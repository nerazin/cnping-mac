// Exercise macOS ICMP loopback and the HTTP callback ring buffer without a GUI.
#define main cnping_main
#include "../cnping.c"
#undef main

#include <pthread.h>
#include <unistd.h>

extern int using_regular_ping;

static void *listen_for_reply(void *arg)
{
    listener((struct PreparedPing *)arg);
    return NULL;
}

static int check_ping(const char *host, const char *interface, unsigned int host_id)
{
    struct PreparedPing *pp = ping_setup(host, interface);
    pthread_t thread;
    if (!pp) return 0;
    pp->pingHostId = (int)host_id;
    if (pthread_create(&thread, NULL, listen_for_reply, pp) != 0) return 0;
    using_regular_ping = 1;
    singleping(pp);
    for (int i = 0; i < 100 && PingData[host_id].globalrx == 0; i++) usleep(20000);
    if (PingData[host_id].globalrx == 0) {
        fprintf(stderr, "No ICMP reply from %s%s\n", host, interface ? " on the selected interface" : "");
        return 0;
    }
    printf("ICMP reply from %s%s verified\n", host, interface ? " on lo0" : "");
    return 1;
}

int main(void)
{
    PingData = calloc(3, sizeof(*PingData));
    if (!PingData) return 1;

    // HTTP sequence numbers keep increasing after the history buffer wraps.
    const int wrapped = PINGCYCLEWIDTH + 3;
    HTTPingCallbackStart(wrapped, 0);
    HTTPingCallbackGot(wrapped, 0);
    if (PingData[0].PingSendTimes[3] <= 0 || PingData[0].globalrx != 1) {
        fprintf(stderr, "HTTP history did not wrap correctly\n");
        return 1;
    }
    puts("HTTP history wrap verified");
    memset(&PingData[0], 0, sizeof(PingData[0]));

    if (!check_ping("127.0.0.1", NULL, 0) ||
        !check_ping("::1", NULL, 1) ||
        !check_ping("127.0.0.1", "lo0", 2)) return 1;
    return 0;
}
