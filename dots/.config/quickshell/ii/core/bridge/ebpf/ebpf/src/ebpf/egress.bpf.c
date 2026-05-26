/* egress.bpf.c — TC egress hook for packet telemetry
 * ==================================================
 * Attaches to the TC (traffic control) egress path and extracts:
 *   - Process ID (pid) and UID
 *   - Destination IP and port
 *   - Protocol (TCP/UDP/ICMP)
 *   - Process name (comm)
 *
 * Writes events to a perf event array for userspace consumption.
 * Does NOT block packets — always returns TC_ACT_OK.
 *
 * Compile:
 *   clang -O2 -target bpf -c egress.bpf.c -o egress.bpf.o \
 *     -I/usr/include/bpf -I/usr/include/linux
 */

#include <linux/bpf.h>
#include <linux/pkt_cls.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/ipv6.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <linux/in.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

#define MAX_COMM_LEN 16

/* Event structure — must match Rust EgressEventRaw */
struct egress_event_t {
    __u32 pid;
    __u32 uid;
    __u32 dst_ip;      // IPv4 only, network byte order
    __u16 dst_port;    // network byte order
    __u8  proto;       // IPPROTO_TCP=6, UDP=17, ICMP=1
    __u8  _pad;
    char  comm[MAX_COMM_LEN];
};

/* Perf event array for sending events to userspace */
struct {
    __uint(type, BPF_MAP_TYPE_PERF_EVENT_ARRAY);
    __uint(key_size, sizeof(__u32));
    __uint(value_size, sizeof(__u32));
} egress_events SEC(".maps");

/* Helper to read process comm (name) */
static __always_inline void get_comm(char *comm) {
    bpf_get_current_comm(comm, MAX_COMM_LEN);
}

SEC("classifier/ase_egress")
int ase_egress(struct __sk_buff *skb) {
    void *data_end = (void *)(long)skb->data_end;
    void *data     = (void *)(long)skb->data;

    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end)
        return TC_ACT_OK;

    // Only process IPv4 for now
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return TC_ACT_OK;

    struct iphdr *ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return TC_ACT_OK;

    struct egress_event_t event = {0};
    event.pid     = bpf_get_current_pid_tgid() >> 32;
    event.uid     = bpf_get_current_uid_gid() & 0xFFFFFFFF;
    event.dst_ip  = ip->daddr;  // already network byte order
    event.proto   = ip->protocol;

    get_comm(event.comm);

    // Extract destination port based on protocol
    if (ip->protocol == IPPROTO_TCP) {
        struct tcphdr *tcp = (void *)ip + (ip->ihl * 4);
        if ((void *)(tcp + 1) > data_end)
            return TC_ACT_OK;
        event.dst_port = tcp->dest;  // network byte order
    } else if (ip->protocol == IPPROTO_UDP) {
        struct udphdr *udp = (void *)ip + (ip->ihl * 4);
        if ((void *)(udp + 1) > data_end)
            return TC_ACT_OK;
        event.dst_port = udp->dest;  // network byte order
    } else {
        event.dst_port = 0;
    }

    // Send event to userspace
    bpf_perf_event_output(skb, &egress_events, BPF_F_CURRENT_CPU,
                          &event, sizeof(event));

    return TC_ACT_OK;  // Always allow packet
}

char _license[] SEC("license") = "GPL";
