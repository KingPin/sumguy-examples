#include <stdio.h>
#include <string.h>
#include <unistd.h>

struct config {
    int port;
    char name[32];
};

static int parse_config(struct config *cfg)
{
    /* Bug on purpose: the caller passes NULL, so this write segfaults. */
    cfg->port = 8080;
    strcpy(cfg->name, "crashy");
    return 0;
}

static int load_settings(void)
{
    struct config *cfg = NULL;
    return parse_config(cfg);
}

int main(void)
{
    fprintf(stderr, "crashy: starting, loading settings\n");
    sleep(2);
    return load_settings();
}
