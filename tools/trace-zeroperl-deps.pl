#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';

use Config     ();
use File::Find qw(find);
use File::Path qw(make_path);
use File::Spec;
use File::Basename   qw(dirname);
use Getopt::Long     qw(GetOptions);
use Module::ScanDeps ();

# Call the main subroutine with command line arguments
exit( main(@ARGV) );

sub main {
    my $opt = getoptions();

    my @trace_inc = grep { -d $_ } (
        $opt->{site_perl_root},
        File::Spec->catdir( $opt->{site_perl_root}, $^O ),
        File::Spec->catdir(
            $opt->{site_perl_root},
            $Config::Config{archname} || ()
        ),
    );

    my $traced_relpaths = {};
    my $traced_modules  = {};

    my @hook_dirs = @trace_inc;
    unshift @INC, sub {
        my ( $self, $filename ) = @_;
        for my $dir (@hook_dirs) {
            my $candidate =
              File::Spec->catfile( $dir, split( '/', $filename ) );
            next unless -f $candidate;
            register_abs_path( $opt->{site_perl_root},
                $traced_relpaths, $traced_modules, $opt->{perl_version},
                $candidate );
            open my $fh, '<', $candidate or die "open $candidate: $!";
            return ( $fh, $candidate );
        }
        return;
    };

    for my $module ( @{ $opt->{use_modules} } ) {
        eval { require $module; $module->import(); 1 }
          or warn "trace use $module failed: $@";
    }

    for my $module ( @{ $opt->{require_modules} } ) {
        eval { require $module; 1 } or warn "trace require $module failed: $@";
    }

    for my $code ( @{ $opt->{eval_snippets} } ) {
        eval $code;    ##no critic qw(ProhibitStringyEval)
        warn "trace eval failed: $@" if $@;
    }

    for my $script ( @{ $opt->{entry_scripts} } ) {
        next unless defined $script && -f $script;
        {
            local @ARGV               = @{ $opt->{entry_args} || [] };
            local *CORE::GLOBAL::exit = sub { die "__TRACE_EXIT__\n" };
            eval { do $script };
            if ($@) {
                next if $@ =~ /^__TRACE_EXIT__/;
                warn "trace do $script failed: $@";
            }
        }
    }

    for my $inc_path ( values %INC ) {
        register_abs_path( $opt->{site_perl_root},
            $traced_relpaths, $traced_modules, $opt->{perl_version},
            $inc_path );
    }

    {
        my @files = grep { defined && -f $_ } @{ $opt->{entry_scripts} };
        for my $module ( @{ $opt->{use_modules} } ) {
            ( my $rel = $module ) =~ s{::}{/}g;
            my $fn = File::Spec->catfile( $opt->{site_perl_root}, "$rel.pm" );
            if ( -f $fn ) {
                push @files, $fn;
            }
        }
        if (@files) {
            my $rv = Module::ScanDeps::scan_deps(
                files   => \@files,
                recurse => 1,
            );
            for my $dep ( values %{ $rv || {} } ) {
                register_abs_path( $opt->{site_perl_root},
                    $traced_relpaths, $traced_modules, $opt->{perl_version},
                    $dep->{file} );
            }
        }
    }

    for my $warmup ( @{ $opt->{warmup_files} } ) {
        next unless defined $warmup && -f $warmup;
        open my $fh, '<', $warmup or die "open $warmup: $!"; ##no critic qw(RequireBriefOpen)
        while ( my $line = <$fh> ) {
            chomp $line;
            next if $line =~ /^\s*$/;
            if ( $line =~
                m{^(?:lib/)?\Q$opt->{perl_version}\E/wasm32-wasi/(.+)$} )
            {
                register_relpath( $traced_relpaths, $traced_modules,
                    $opt->{perl_version},
                    "lib/$opt->{perl_version}/wasm32-wasi/$1" );
                my $module = module_name_from_relpath($1);
                $traced_modules->{$module} = 1 if defined $module;
            }
            elsif ( index( $line, $opt->{site_perl_root} ) == 0 ) {
                register_abs_path( $opt->{site_perl_root},
                    $traced_relpaths, $traced_modules, $opt->{perl_version},
                    $line );
            }
            else {
                $line = normalize_relpath($line);
                register_relpath( $traced_relpaths, $traced_modules,
                    $opt->{perl_version}, $line );
                if ( $line =~
                    m{^lib/\Q$opt->{perl_version}\E/wasm32-wasi/(.+)$} )
                {
                    my $module = module_name_from_relpath($1);
                    $traced_modules->{$module} = 1 if defined $module;
                }
            }
        }
        close $fh;
    }

    if ( defined $opt->{allowlist} && -f $opt->{allowlist} ) {
        open my $fh, '<', $opt->{allowlist} or die "open $opt->{allowlist}: $!";  ##no critic qw(RequireBriefOpen)
        while ( my $line = <$fh> ) {
            chomp $line;
            $line =~ s/\s+#.*$//;
            next if $line =~ /^\s*$/;
            $line = normalize_relpath($line);
            register_relpath( $traced_relpaths, $traced_modules,
                $opt->{perl_version}, $line );
            if ( $line =~ m{^lib/\Q$opt->{perl_version}\E/wasm32-wasi/(.+)$} ) {
                my $module = module_name_from_relpath($1);
                $traced_modules->{$module} = 1 if defined $module;
            }
        }
        close $fh;
    }

    expand_package_trees(
        $opt->{expand_explicit_package_trees},
        $opt->{expand_dependency_package_trees},
        $opt->{site_perl_root},
        $opt->{perl_version},
        $opt->{explicit_packages},
        $opt->{use_modules},
        $opt->{require_modules},
        $traced_relpaths,
        $traced_modules
    );

    include_auto_companion_artifacts(
        $opt->{site_perl_root}, $traced_relpaths, $traced_modules,
        $opt->{perl_version},   $opt->{native_prefix}
    );

    my @ext_names;
    my %seen_ext;
    find(
        sub {
            return unless /\.a$/;
            my $archive = $File::Find::name;
            for my $module ( keys %{$traced_modules} ) {
                ( my $module_path = $module ) =~ s{::}{/}g;
                if ( $archive =~ m{/auto/\Q$module_path\E/[^/]+\.a$} ) {
                    $seen_ext{$module_path} = 1;
                }
            }
        },
        $opt->{native_prefix},
    );
    @ext_names = sort keys %seen_ext;

    for my $path ( $opt->{output}, $opt->{xs_output} ) {
        my $dir = dirname($path);
        make_path($dir) if defined $dir && length $dir && !-d $dir;
    }

    open my $out_fh, '>', $opt->{output} or die "open $opt->{output}: $!";
    print {$out_fh} "$_\n" for sort keys %{$traced_relpaths};
    close $out_fh;

    open my $xs_fh, '>', $opt->{xs_output} or die "open $opt->{xs_output}: $!";
    print {$xs_fh} "$_\n" for @ext_names;
    close $xs_fh;

    return(0);
}

sub getoptions {
    my $opt = {
        site_perl_root                  => undef,
        native_prefix                   => undef,
        perl_version                    => undef,
        output                          => undef,
        xs_output                       => undef,
        allowlist                       => undef,
        warmup_files                    => [],
        use_modules                     => [],
        require_modules                 => [],
        explicit_packages               => [],
        eval_snippets                   => [],
        entry_scripts                   => [],
        entry_args                      => [],
        expand_explicit_package_trees   => 1,
        expand_dependency_package_trees => 1,
    };

    GetOptions(
        'site-perl-root=s'               => \$opt->{site_perl_root},
        'native-prefix=s'                => \$opt->{native_prefix},
        'perl-version=s'                 => \$opt->{perl_version},
        'output=s'                       => \$opt->{output},
        'xs-output=s'                    => \$opt->{xs_output},
        'allowlist=s'                    => \$opt->{allowlist},
        'warmup-file=s@'                 => $opt->{warmup_files},
        'use=s@'                         => $opt->{use_modules},
        'require=s@'                     => $opt->{require_modules},
        'explicit-package=s@'            => $opt->{explicit_packages},
        'eval=s@'                        => $opt->{eval_snippets},
        'entry-script=s@'                => $opt->{entry_scripts},
        'entry-arg=s@'                   => $opt->{entry_args},
        'expand-explicit-package-trees!' =>
          \$opt->{expand_explicit_package_trees},
        'expand-dependency-package-trees!' =>
          \$opt->{expand_dependency_package_trees},
    ) or die "bad options\n";

    die "--native-prefix required\n" unless defined $opt->{native_prefix};
    die "--perl-version required\n"  unless defined $opt->{perl_version};
    die "--output required\n"        unless defined $opt->{output};
    die "--xs-output required\n"     unless defined $opt->{xs_output};

    $opt->{site_perl_root} //=
      File::Spec->catdir( $opt->{native_prefix}, 'lib', 'perl5', 'site_perl',
        $opt->{perl_version} );

    return $opt;
}

sub split_module_list {
    my ( @in ) = @_;
    my @items;
    for my $raw (@in) {
        next unless defined $raw;
        for my $item ( split /,/, $raw ) {
            $item =~ s/^\s+//;
            $item =~ s/\s+$//;
            next unless length $item;
            push @items, $item;
        }
    }
    return @items;
}

sub normalize_module_name {
    my ($module) = @_;
    return unless defined $module;
    $module =~ s/^\s+//;
    $module =~ s/\s+$//;
    return unless length $module;
    $module =~ s{\.(?:pm|pl)$}{};
    $module =~ s{/}{::}g;
    return $module;
}

sub module_path_from_name {
    my ($module) = @_;
    return unless defined $module;
    $module =~ s{::}{/}g;
    return $module;
}

sub normalize_relpath {
    my ($path) = @_;
    $path =~ s{\\}{/}g;
    $path =~ s{^\./}{};
    return $path;
}

sub module_name_from_relpath {
    my ($relpath) = @_;
    return unless $relpath    =~ /\.(?:pm|pl)$/;
    ( my $module = $relpath ) =~ s/\.(?:pm|pl)$//;
    $module                   =~ s{/}{::}g;
    return $module;
}

sub register_relpath {
    my ( $traced_relpaths, $traced_modules, $perl_version, $relpath ) = @_;
    return unless defined $relpath;
    $relpath = normalize_relpath($relpath);
    return unless length $relpath;
    $traced_relpaths->{$relpath} = 1;
    if ( $relpath =~ m{^lib/\Q$perl_version\E/wasm32-wasi/(.+)$} ) {
        my $module = module_name_from_relpath($1);
        $traced_modules->{$module} = 1 if defined $module;
    }
}

sub register_abs_path {
    my (
        $site_perl_root, $traced_relpaths, $traced_modules,
        $perl_version,   $path
    ) = @_;
    return unless defined $path && -f $path;
    my $rel;
    if ( index( $path, $site_perl_root ) == 0 ) {
        $rel = File::Spec->abs2rel( $path, $site_perl_root );
        $rel = normalize_relpath($rel);
        register_relpath( $traced_relpaths, $traced_modules, $perl_version,
            "lib/$perl_version/wasm32-wasi/$rel" );
        my $module = module_name_from_relpath($rel);
        $traced_modules->{$module} = 1 if defined $module;
    }
}

sub register_site_relative_abs_path {
    my (
        $site_perl_root, $traced_relpaths, $traced_modules,
        $perl_version,   $abs_path
    ) = @_;
    return unless defined $abs_path && -f $abs_path;
    return unless index( $abs_path, $site_perl_root ) == 0;
    my $rel = File::Spec->abs2rel( $abs_path, $site_perl_root );
    register_relpath( $traced_relpaths, $traced_modules, $perl_version,
        "lib/$perl_version/wasm32-wasi/" . normalize_relpath($rel) );
}

sub include_autosplit_targets {
    my (
        $site_perl_root, $traced_relpaths, $traced_modules,
        $perl_version,   $autosplit_ix
    ) = @_;
    return unless -f $autosplit_ix;
    open my $ix_fh, '<', $autosplit_ix or die "open $autosplit_ix: $!";  ##no critic qw(RequireBriefOpen)  
    while ( my $line = <$ix_fh> ) {
        chomp $line;
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*#/;
        my ($target) = split /\s+/, $line, 2;
        next unless defined $target && length $target;
        my $target_path =
          File::Spec->catfile( dirname($autosplit_ix), split( '/', $target ) );
        register_site_relative_abs_path(
            $site_perl_root, $traced_relpaths, $traced_modules,
            $perl_version,   $target_path
        );
    }
    close $ix_fh;
}

sub include_auto_companion_artifacts {
    my (
        $site_perl_root, $traced_relpaths, $traced_modules,
        $perl_version,   $native_prefix
    ) = @_;

    my %module_paths;
    for my $module ( keys %{$traced_modules} ) {
        ( my $module_path = $module ) =~ s{::}{/}g;
        $module_paths{$module_path} = 1;
    }

    for my $module_path ( sort keys %module_paths ) {
        my $auto_dir = File::Spec->catdir( $site_perl_root, 'auto',
            split( '/', $module_path ) );
        next unless -d $auto_dir;

        my $autosplit_ix = File::Spec->catfile( $auto_dir, 'autosplit.ix' );
        if ( -f $autosplit_ix ) {
            register_site_relative_abs_path(
                $site_perl_root, $traced_relpaths, $traced_modules,
                $perl_version,   $autosplit_ix
            );
            include_autosplit_targets(
                $site_perl_root, $traced_relpaths, $traced_modules,
                $perl_version,   $autosplit_ix
            );
        }

        my $extra_libs = File::Spec->catfile( $auto_dir, 'extralibs.ld' );
        register_site_relative_abs_path(
            $site_perl_root, $traced_relpaths, $traced_modules,
            $perl_version,   $extra_libs
        ) if -f $extra_libs;
    }
}

sub include_module_package_tree {
    my (
        $site_perl_root, $traced_relpaths, $traced_modules,
        $perl_version,   $module
    ) = @_;
    my $module_path = module_path_from_name($module);
    return unless defined $module_path && length $module_path;

    for my $suffix ( '.pm', '.pl' ) {
        my $module_file = File::Spec->catfile( $site_perl_root,
            split( '/', $module_path . $suffix ) );
        register_site_relative_abs_path(
            $site_perl_root, $traced_relpaths, $traced_modules,
            $perl_version,   $module_file
        ) if -f $module_file;
    }

    my $module_dir =
      File::Spec->catdir( $site_perl_root, split( '/', $module_path ) );
    return unless -d $module_dir;

    find(
        sub {
            return unless -f $_;
            return unless /\.(?:pm|pl|al)$/;
            register_site_relative_abs_path(
                $site_perl_root, $traced_relpaths, $traced_modules,
                $perl_version,   $File::Find::name
            );
        },
        $module_dir,
    );
}

sub expand_package_trees {
    my (
        $expand_explicit_package_trees, $expand_dependency_package_trees,
        $site_perl_root,                $perl_version,
        $explicit_packages,             $use_modules,
        $require_modules,               $traced_relpaths,
        $traced_modules
    ) = @_;
    my %seen;

    if ($expand_explicit_package_trees) {
        my @explicit_modules =
          split_module_list( @{$explicit_packages}, @{$use_modules},
            @{$require_modules} );
        for my $module (@explicit_modules) {
            $module = normalize_module_name($module);
            next unless defined $module;
            next if $seen{"explicit:$module"}++;
            include_module_package_tree(
                $site_perl_root, $traced_relpaths, $traced_modules,
                $perl_version,   $module
            );
        }
    }

    if ($expand_dependency_package_trees) {
        for my $module ( sort keys %{$traced_modules} ) {
            next if $seen{"dependency:$module"}++;
            include_module_package_tree(
                $site_perl_root, $traced_relpaths, $traced_modules,
                $perl_version,   $module
            );
        }
    }
}

