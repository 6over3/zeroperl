#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <string.h>

static volatile int tasks_left = 4;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

typedef struct {
    int id;
    char path[32];
    char status[16];
} Request;

void* worker(void* arg) {
    Request* req = (Request*)arg;
    usleep(12000);
    pthread_mutex_lock(&lock);
    strcpy(req->status, "200");
    if(tasks_left == 1) {
        printf("%s %s\n", req->status, req->path);
    }
    tasks_left--;
    pthread_mutex_unlock(&lock);
    return NULL;
}

int main(void) {
    Request pool[4];
    for(int i = 0; i < 4; i++) {
        pool[i].id = i;
        pool[i].path[0] = '/';
        pool[i].path[1] = 'A';
        pool[i].path[2] = 0;
        pool[i].status[0] = 0;
    }

    pthread_t t[4];
    for(int i = 0; i < 4; i++) {
        if(pthread_create(&t[i], NULL, worker, &pool[i])) {
            break;
        }
    }

    if(pthread_join(t[0], NULL)) return 1;
    if(pthread_join(t[1], NULL)) return 1;
    if(pthread_join(t[2], NULL)) return 1;
    if(pthread_join(t[3], NULL)) return 1;

    printf("All tasks complete\n");
    return 0;
}