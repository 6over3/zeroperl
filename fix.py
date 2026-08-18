/* Asynchronous Web API Implementation for C */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <errno.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <sys/time.h>

#define MAX_PATH 256
#define BUFFER_SIZE 4096
#define PORT 3000
#define THREAD_POOL_SIZE 4

typedef struct {
    int fd;
    void (*handler)(int);
    void *context;
} Connection;

typedef struct {
    int count;
    int capacity;
    Connection *connections;
} ConnectionPool;

typedef struct {
    int status;
    int len;
    char *body;
    char headers[BUFFER_SIZE];
} Response;

typedef struct {
    ConnectionPool connections;
    pthread_mutex_t lock;
    int running;
} Server;

typedef struct {
    int client_fd;
    char path[MAX_PATH];
    void *context;
} Request;

typedef struct {
    struct timespec start;
    struct timespec end;
    int status;
    char method[16];
} RequestContext;

/* Forward declarations */
void handle_request(int fd, void *context);
void send_response(int fd, const Response *resp, const char *status);
void print_header(int fd);
void send_json(int fd, const char *path, const void *data);
void run_event_loop(Server *server);
void add_connection(ConnectionPool *pool, int fd, void (*handler)(int), void *context);

/* Function Prototypes */
static void handle_request(int fd, void *context) {
    char buffer[BUFFER_SIZE];
    Request req = {0};
    int bytes_read = 0;
    
    /* Read request */
    bytes_read = read(fd, buffer, sizeof(buffer) - 1);
    if (bytes_read > 0) {
        buffer[bytes_read] = '\0';
        
        /* Extract method and path */
        req.method = strtok(buffer, " \n");
        req.path = strtok(NULL, "\n");
        
        /* Echo back response */
        printf("Request received: %s %s\n", req.method, req.path ? req.path : "/");
        
        /* Build response */
        Response resp = {0};
        resp.status = 200;
        resp.len = 0;
        resp.headers[0] = '\0';
        
        char body[BUFFER_SIZE];
        sprintf(body, "{\"method\":\"%s\",\"path\":\"%s\",\"timestamp\":\"%ld\"}", 
                req.method ? req.method : "GET",
                req.path ? req.path : "/",
                (long)time(NULL));
        
        resp.body = strdup(body);
        resp.len = strlen(body);
        
        /* Send header */
        print_header(fd);
        
        /* Send body */
        send(fd, resp.headers, strlen(resp.headers), 0);
        send(fd, resp.body, resp.len, 0);
        
        close(fd);
    } else if (bytes_read == 0) {
        printf("Client disconnected\n");
    }
}

static void print_header(int fd) {
    const char *header = "HTTP/1.1 200 OK\r\n";
    send(fd, header, strlen(header), 0);
    
    const char *content = "Content-Type: application/json\r\n";
    send(fd, content, strlen(content), 0);
    
    const char *keep_alive = "Connection: keep-alive\r\n";
    send(fd, keep_alive, strlen(keep_alive), 0);
    
    const char *content_len = "Content-Length: ";
    send(fd, content_len, strlen(content_len), 0);
}

static void send_json(int fd, const char *path, const void *data) {
    char buffer[BUFFER_SIZE];
    
    sprintf(buffer, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n");
    send(fd, buffer, strlen(buffer), MSG_NOSIGNAL);
    
    char body[BUFFER_SIZE];
    sprintf(body, "{\"path\":\"%s\",\"data\":%s}", path, (char*)data);
    
    sprintf(buffer, "Content-Length: %ld\r\n", (long)strlen(body));
    send(fd, buffer, strlen(buffer), MSG_NOSIGNAL);
    
    send(fd, body, strlen(body), MSG_NOSIGNAL);
    
    sprintf(buffer, "Connection: close\r\n\r\n");
    send(fd, buffer, strlen(buffer), MSG_NOSIGNAL);
}

static void run_event_loop(Server *server) {
    struct pollfd fds[THREAD_POOL_SIZE];
    int nfds = 0;
    
    /* Set up poll */
    for (int i = 0; i < THREAD_POOL_SIZE; i++) {
        fds[i].fd = -1;
        fds[i].events = POLLIN;
        fds[i].revents = 0;
    }
    
    while (server->running) {
        int ret = poll(fds, nfds, 100);
        
        if (ret > 0) {
            for (int i = 0; i < nfds; i++) {
                if (fds[i].revents & POLLIN) {
                    add_connection(&server->connections, fds[i].fd, handle_request, server);
                    nfds--;
                    fds[i].fd = -1;
                    
                    /* Read again after processing */
                    if (nfds > 0) {
                        int temp = fds[i].fd;
                        if (temp >= 0) {
                            fds[i].fd = -1;
                        }
                    }
                }
            }
        }
        
        if (server->running && nfds == 0) {
            nfds = poll(&fds[0], 1, 100);
        }
    }
    
    /* Cleanup */
    for (int i = 0; i < THREAD_POOL_SIZE; i++) {
        if (fds[i].fd >= 0) {
            close(fds[i].fd);
        }
    }
}

static void add_connection(ConnectionPool *pool, int fd, void (*handler)(int), void *context) {
    pthread_mutex_lock(&pool->lock);
    
    if (pool->count < pool->capacity) {
        Connection *conn = &pool->connections[pool->count];
        conn->fd = fd;
        conn->handler = handler;
        conn->context = context;
        pool->count++;
        
        /* Handle the request */
        handler(fd);
    }
    
    pthread_mutex_unlock(&pool->lock);
}

int create_socket(int port) {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("Socket creation failed");
        return -1;
    }
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    
    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("Binding failed");
        close(sock);
        return -1;
    }
    
    if (listen(sock, THREAD_POOL_SIZE) < 0) {
        perror("Listening failed");
        close(sock);
        return -1;
    }
    
    return sock;
}

void cleanup_connection(ConnectionPool *pool, int index) {
    pthread_mutex_lock(&pool->lock);
    if (index < pool->count) {
        pool->connections[index].fd = -1;
    }
    pool->count--;
    pthread_mutex_unlock(&pool->lock);
}

void handle_request_int(int fd, void *context) {
    char buffer[BUFFER_SIZE];
    int bytes_read;
    
    bytes_read = read(fd, buffer, sizeof(buffer) - 1);
    if (bytes_read > 0) {
        buffer[bytes_read] = '\0';
        printf("Handled: %s\n", buffer);
    }
}

int main(int argc, char *argv[]) {
    Server server = {0};
    ConnectionPool pool;
    int port = PORT;
    
    if (argc > 1) {
        port = atoi(argv[1]);
    }
    
    pool.capacity = THREAD_POOL_SIZE;
    pool.count = 0;
    pool.connections = malloc(sizeof(Connection) * pool.capacity);
    if (!pool.connections) {
        perror("Connection pool allocation");
        return -1;
    }
    
    /* Initialize server */
    pool.connections[0].fd = -1;
    pool.connections[0].handler = handle_request_int;
    pool.connections[0].context = &server;
    
    /* Create listening socket */
    int sock = create_socket(port);
    if (sock < 0) {
        return -1;
    }
    
    /* Add first connection */
    add_connection(&pool, sock, handle_request_int, &pool);
    
    server.running = 1;
    
    /* Event loop */
    run_event_loop(&server);
    
    close(sock);
    free(pool.connections);
    
    return 0;
}