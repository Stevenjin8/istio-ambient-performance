# Finding why CRR is so slow

First, get access to the root node running the client.

```bash
k debug -it -n ambient node/aks-server-19481340-vmss000001 --image=ubuntu
```

This will let us access the root file system under /host.

```sh
chroot host
bash
```

We can see all the running pods with

```bash
crictl pods
```

Install termshark

```bash
apt install termshark
export TERM=xterm-256color
```

Exec into the client

```
k exec -n ambient client-6b8c4d6556-gm77t -it -- bash
```

Then we can run `termshark -i istioin` in the node and `netcat server 6789` in the client.
Hmm.
It seems like we only see a SYN packet from the server, but it comes from the right address.
There are also no `FIN`s when closing the connection.

```
0.00000 10.224.1.14  10.224.0.144 TCP        74      35171 → 15008 [SYN] Seq=0 Win=642
```

Doing `termshark -i istioout` doesn't give anything.
Nor do I see anything related to port `6789` on `lo`, and `eth0`.
So there must be interfaces `ifconfig` is not showing.

This seems like a lead https://stackoverflow.com/questions/37860936/find-out-which-network-interface-belongs-to-docker-container
The SO thread uses Docker, but it seems like AKS clusters use `crictl`.
They should be similar enough.

`crictl pods` shows all the pods
Then we can inspect the server pod with `crictl inspectp 40ad4469d1488 | less`.
Nothing useful shows up when I search `container`, but I see a pid of `3292722`.
Running `ls /proc` shows us the same pid exists, but following on the `nsenter` gives me permissions errors.

It seems like `crictl ps` gives container ids. `crictl inspect c1952203db195` shows the container PID.
Man, everything in `/proc/3292881/ns` is blocked.
But I can see the active connections with `net/tcp`

`crictl exec -it c1952203db195 bash` gives me root access to the container/its namespaces
So maybe I can sniff traffic there.
Going into the server container, I see traffic on `eth0`

```
43   94.234 10.224.0.1 10.224.1.1 TCP       66     6789 → 38765 [ACK] Seq=1 Ack=6
```

Crickets in `lo`. Now we look in Ztunnel `crictl exec -it 1b180d870e2a3 bash`

Doesn't seem like I can update

```
$ apt update -y
E: List directory /var/lib/apt/lists/partial is missing. - Acquire (30: Read-only file system)
```

Inspecting the Ztunnel container isn't very helpful either
Running `ip netns` shows two network namespaces, 0 and 2.
Where is 1?

Ok so just going throught the other available interfaces.
`enP64207s1` seems to have the HBONE connection data since you have to apply filter `tcp.port == 15008` to see anything interesting.

```
1031   12.29663 10.224.1.14   10.224.0.144  TLSv1.2     100      Application Data
1032   12.29709 10.224.0.144  10.224.1.14   TLSv1.2     100      Application Data
1033   12.29724 10.224.1.14   10.224.0.144  TCP         66       57551 → 15008 [ACK] Seq=35 Ack=35 Win
```
Note the lack of an `ACK` between 1031 and 1032. We also see TLS handshake.
The `1.14` address is from the eth0 of the client pod
and i guess the `0.144` must be from another pod.

The `en` interface looks interesting

```
1267 11.679 10.224.0.1 10.224.1.1 TCP       74     15008 → 44119 [SYN, ACK] Seq=0
1268 11.680 10.224.1.1 10.224.0.1 TCP       66     44119 → 15008 [ACK] Seq=1 Ack=
1269 11.680 10.224.1.1 10.224.0.1 TLSv1     254    Client Hello
1270 11.680 10.224.0.1 10.224.1.1 TCP       66     15008 → 44119 [ACK] Seq=1 Ack=
1271 11.681 10.224.0.1 10.224.1.1 TLSv1.3   1019   Server Hello, Change Cipher Sp
1272 11.681 10.224.1.1 10.224.0.1 TCP       66     44119 → 15008 [ACK] Seq=189 Ac
1273 11.682 10.224.1.1 10.224.0.1 TLSv1.3   856    Change Cipher Spec, Applicatio
1273 11.682 10.224.1.1 10.224.0.1 TLSv1.3   856    Change Cipher Spec, Applicatio
1274 11.682 10.224.1.1 10.224.0.1 TLSv1.3   112    Application Data
1275 11.682 10.224.0.1 10.224.1.1 TCP       66     15008 → 44119 [ACK] Seq=954 Ac
1276 11.682 10.224.1.1 10.224.0.1 TLSv1.3   328    Application Data
1277 11.682 10.224.0.1 10.224.1.1 TLSv1.3   1781   Application Data, Application
1278 11.683 10.224.1.1 10.224.0.1 TCP       66     44119 → 15008 [ACK] Seq=1287 A
1279 11.683 10.224.0.1 10.224.1.1 TLSv1.3   110    Application Data
1280 11.683 10.224.1.1 10.224.0.1 TLSv1.3   97     Application Data         
1283 11.724 10.224.1.1 10.224.0.1 TCP       66     44119 → 15008 [ACK] Seq=1318 A <---- this one!
1284 11.724 10.224.0.1 10.224.1.1 TLSv1.3   122    Application Data
1285 11.724 10.224.1.1 10.224.0.1 TCP       66     44119 → 15008 [ACK] Seq=1318 A
```

We see that there is a 40 ms jump there.

Now we inspect istioout

```
No. - Time - Source -    Destination Protocol - Length Info -
1     0.0000 10.224.1.14 10.0.126.76 TCP        74     40432 → 6789 [SYN] Seq=0 Win=642
```

Same deal just the syn.
Nothing in istioin.
The en port is good

```
No. - Time -  Source -     Destination  Protocol - Length  Info -                          
1051  18.1938 10.224.1.14  10.224.0.144 TCP        74      59753 → 15008 [SYN] Seq=0 Win=64
1052  18.1953 10.224.1.14  10.224.0.144 TCP        66      59753 → 15008 [ACK] Seq=1 Ack=1
1053  18.1955 10.224.1.14  10.224.0.144 TLSv1      254     Client Hello
1054  18.1956 10.224.0.144 10.224.1.14  TCP        66      15008 → 59753 [ACK] Seq=1 Ack=18
1055  18.1960 10.224.0.144 10.224.1.14  TLSv1.3    1018    Server Hello, Change Cipher Spec
1056  18.1960 10.224.1.14  10.224.0.144 TCP        66      59753 → 15008 [ACK] Seq=189 Ack=
1057  18.1969 10.224.1.14  10.224.0.144 TLSv1.3    856     Change Cipher Spec, Application
1058  18.1969 10.224.1.14  10.224.0.144 TLSv1.3    112     Application Data                
1059  18.1970 10.224.0.144 10.224.1.14  TCP        66      15008 → 59753 [ACK] Seq=953 Ack=
1060  18.1971 10.224.1.14  10.224.0.144 TLSv1.3    327     Application Data
1061  18.1974 10.224.0.144 10.224.1.14  TLSv1.3    1781    Application Data, Application Da
1062  18.1976 10.224.1.14  10.224.0.144 TCP        66      59753 → 15008 [ACK] Seq=1286 Ack
1063  18.1977 10.224.1.14  10.224.0.144 TLSv1.3    97      Application Data
1064  18.1977 10.224.0.144 10.224.1.14  TLSv1.3    110     Application Data                
1065  18.2392 10.224.0.144 10.224.1.14  TCP        66      15008 → 59753 [ACK] Seq=2712 Ack <-- here
1066  18.2425 10.224.1.14  10.224.0.144 TCP        66      59753 → 15008 [ACK] Seq=1317 Ack
1067  18.2427 10.224.0.144 10.224.1.14  TLSv1.3    122     Application Data                
1068  18.2428 10.224.1.14  10.224.0.144 TCP        66      59753 → 15008 [ACK] Seq=1317 Ack
```

We see the same 40ms jump.
Also notice that in this one, there is only a `syn` but no `synack`, but the reverse is true for the other one.
It would be so nice to see the application data.
Wait, I see the same thing in eth0, but with the full handshake.
Also kind weird that the slowdown is form an ACK.

So I should take a look at what this "Application data" is.
Do I really want to try to decode the tls? I can probably just run it locally and compare.
Ideally, I want to look at the ztunnel raw stuff.
I wonder what is going on in the container.

## Day 2

Ok so today I want to try to see what happens when I do everything locally.

There is a `LOCAL.md` file in the repo and its pretty useful.
Following the instructions, I get a Ztunnel activated and start listening to `lo` with `termshark -i lo -f `tcp port 15008`.
In one shell I run `nc -l 9000`.
From the other, I run `sudo -u iptables1 nc localhost 9000`.
We see that Ztunnel logs

```
2023-07-13T18:15:01.606984Z  INFO outbound{id=c829d7ab47229360489706fca0c6da9b}: ztunnel::proxy::outbound: proxy to 127.0.0.1:9000 using HBONE via 127.0.0.1:15008 type Direct
```

So there is an HBONE connection.
Ta
In Termshark, we see
```
1       0.000000  127.0.0.1        127.0.0.1        TCP            74       45260 → 15008 [SYN] Seq=0 Win=65495 Len=0 MSS
2       0.000014  127.0.0.1        127.0.0.1        TCP            74       15008 → 45260 [SYN, ACK] Seq=0 Ack=1 Win=6548
3       0.000024  127.0.0.1        127.0.0.1        TCP            66       45260 → 15008 [ACK] Seq=1 Ack=1 Win=65536 Len
4       0.000249  127.0.0.1        127.0.0.1        TLSv1          254      Client Hello
5       0.000265  127.0.0.1        127.0.0.1        TCP            66       15008 → 45260 [ACK] Seq=1 Ack=189 Win=65408 L
6       0.000518  127.0.0.1        127.0.0.1        TLSv1.3        1011     Server Hello, Change Cipher Spec, Application
7       0.000531  127.0.0.1        127.0.0.1        TCP            66       45260 → 15008 [ACK] Seq=189 Ack=946 Win=64640
8       0.001435  127.0.0.1        127.0.0.1        TLSv1.3        847      Change Cipher Spec, Application Data
9       0.001466  127.0.0.1        127.0.0.1        TLSv1.3        112      Application Data
10      0.001581  127.0.0.1        127.0.0.1        TLSv1.3        305      Application Data
11      0.001731  127.0.0.1        127.0.0.1        TLSv1.3        1781     Application Data, Application Data           
12      0.001790  127.0.0.1        127.0.0.1        TLSv1.3        97       Application Data
13      0.001811  127.0.0.1        127.0.0.1        TLSv1.3        110      Application Data
14      0.048371  127.0.0.1        127.0.0.1        TCP            66       45260 → 15008 [ACK] Seq=1286 Ack=2705 Win=655
15      0.048404  127.0.0.1        127.0.0.1        TLSv1.3        123      Application Data                             
16      0.048411  127.0.0.1        127.0.0.1        TCP            66       45260 → 15008 [ACK] Seq=1286 Ack=2762 Win=655
```

Kinda sucky that I can't see the src and dst ports, but the point is the same.
We see the 45ms wait time as in the cluster.
So I should probably find out what the heck is going on in here.
Also, we see the same story when running in debug mode.

`outbound.rs:307` seems like a good place to break.

```
let response = connection.send_request(request).await?;
```

`connection` has a ssl-connection embedded? and `request` is an http request(?).
Let's take a look!

We run the server with `rust-gdb` using `rust-gdb --args env FAKE_CA="true" XDS_ADDRESS="" LOCAL_XDS_PATH=./examples/localhost.yaml ./out/rust/debug/ztunnel`
We see the same slowdown when running Ztunnel in rust-gdb
Ok so the request headers are a dict which are kinda bad to work with in gdb.

Changing the code to just print the headers, we get this

```
2023-07-13T20:15:53.998680Z  INFO inbound{id=c518fb4094f0010121d8f064465f2a3d peer_ip=127.0.0.1 peer_id=spiffe:///ns/default/sa/default}: ztunnel::proxy::inbound: got CONNECT request to 127.0.0.1:9000
2023-07-13T20:16:20.960274Z  INFO outbound{id=c518fb4094f0010121d8f064465f2a3d}: ztunnel::proxy::outbound: complete dur=26.96955872s
2023-07-13T20:16:23.543826Z  INFO outbound{id=c1b1fdef3403e33de663898e733fb965}: ztunnel::proxy::outbound: proxy to 127.0.0.1:9000 using HBONE via 127.0.0.1:15008 type Direct
"baggage": "k8s.cluster.name=Kubernetes,k8s.namespace.name=default,k8s..name=,service.name=,service.version="
"forwarded": "for=127.0.0.1"
"traceparent": "00-c1b1fdef3403e33de663898e733fb965-c9ba28ab04c2595e-00"
```

But looking at the termshark output, it seems like this request happens after the slowdown.
Ok, so just reading how we got `connection`, it seems like we're doing some SSL stuff in `outbound.rs:269`.
Honestly, I don't really want to dive into profiling just yet, so I'm going to insert breakpoints.
It still really bothers me that the slow down is between data packet and an ack packet.
Like, shouldn't this be happening at the kernel?
Ok, another thing that's weird is that this occurs only on the first connection. After that, its only three packets

Lost the output, but this is what I've learned.

COULD THIS BE A DELAYED ACK THING.

```
49     135.5874 127.0.0.1      127.0.0.1      TLSv1.3      142      Application Data
50     135.5877 127.0.0.1      127.0.0.1      TLSv1.3      122      Application Data
51     135.5877 127.0.0.1      127.0.0.1      TCP          66       51458 → 15008 [ACK] Seq=1838 Ack=3108
52     135.5878 127.0.0.1      127.0.0.1      TLSv1.3      100      Application Data                      
53     135.6316 127.0.0.1      127.0.0.1      TCP          66       15008 → 51458 [ACK] Seq=3108 Ack=1872
...
58     191.8677 127.0.0.1      127.0.0.1      TLSv1.3      142      Application Data
59     191.8680 127.0.0.1      127.0.0.1      TLSv1.3      122      Application Data
60     191.8680 127.0.0.1      127.0.0.1      TCP          66       51458 → 15008 [ACK] Seq=1979 Ack=3195
61     191.8681 127.0.0.1      127.0.0.1      TLSv1.3      100      Application Data                      
62     191.9156 127.0.0.1      127.0.0.1      TCP          66       15008 → 51458 [ACK] Seq=3195 Ack=2013
```

So we see that this is an ack thing.
One thing I will add is the the segments right before the delay do contain the `PSH` flag
So i dont think its a delayed ack thing because this has nothing to do with sending data.
When I run it through the echo server, things are fast locally.
What about in a cluster?

So from the perspective of the client, this is happening

```
...
35     610.560 10.0.126.76   10.224.1.14   TCP         74      6789 → 56722 [SYN, ACK] Seq=0 Ack=1 Wi
36     610.560 10.224.1.14   10.0.126.76   TCP         66      56722 → 6789 [ACK] Seq=1 Ack=1 Win=642
37     610.560 10.224.1.14   10.0.126.76   TCP         69      56722 → 6789 [PSH, ACK] Seq=1 Ack=1 Wi
38     610.560 10.0.126.76   10.224.1.14   TCP         66      6789 → 56722 [ACK] Seq=1 Ack=4 Win=652
39     610.607 10.0.126.76   10.224.1.14   TCP         69      6789 → 56722 [PSH, ACK] Seq=1 Ack=4 Wi
40     610.607 10.224.1.14   10.0.126.76   TCP         66      56722 → 6789 [ACK] Seq=4 Ack=4 Win=642
```

pretty standard, but the response from the server is delayed.
From the server side, we see

```
...
22     88.8657 10.224.0.144  10.224.1.14   TCP         74      6789 → 38421 [SYN, ACK] Seq=0 Ack=1 Wi
23     88.8657 10.224.1.14   10.224.0.144  TCP         66      38421 → 6789 [ACK] Seq=1 Ack=1 Win=642
24     88.9105 10.224.1.14   10.224.0.144  TCP         69      38421 → 6789 [PSH, ACK] Seq=1 Ack=1 Wi
25     88.9106 10.224.0.144  10.224.1.14   TCP         66      6789 → 38421 [ACK] Seq=1 Ack=4 Win=652
26     88.9108 10.224.0.144  10.224.1.14   TCP         69      6789 → 38421 [PSH, ACK] Seq=1 Ack=4 Wi
27     88.9108 10.224.1.14   10.224.0.144  TCP         66      38421 → 6789 [ACK] Seq=4 Ack=4 Win=642
```

It takes quite a while for the first packet to arrive. But afterwards, it takes like 1ms for a roundtrip.

```
17     114.4332 10.224.1.14    10.0.126.76    TCP          83       42202 → 6789 [PSH, ACK] Seq=18 Ack=18
18     114.4344 10.0.126.76    10.224.1.14    TCP          83       6789 → 42202 [PSH, ACK] Seq=18 Ack=35
19     114.4344 10.224.1.14    10.0.126.76    TCP          66       42202 → 6789 [ACK] Seq=35 Ack=35 Win=6
20     139.7572 10.224.1.14    10.0.126.76    TCP          73       42202 → 6789 [PSH, ACK] Seq=35 Ack=35
21     139.7583 10.0.126.76    10.224.1.14    TCP          73       6789 → 42202 [PSH, ACK] Seq=35 Ack=42 
22     139.7583 10.224.1.14    10.0.126.76    TCP          66       42202 → 6789 [ACK] Seq=42 Ack=42 Win=6
```

## Day 3

I think the best way is still to look at the namespaces.
After messing around I found a way to get access to the network namespaces without having to go through `/proc/<pid>/ns`.
Running `ls` in `/var/run/netns` lists all the networking namespaces.
Then, running something along the lines of `ip netns exec cni-815ecda1-a6f9-f1c3-0625-ee276737c4d0 <command>` will run that in the namespace.

Another thing I've wanted to do for a bit is see the actual encrypted tcp traffic.
Locally, I can set the `SSLKEYLOGFILE` or `SSLKEYLOG` environemtn variable.
Then, when I `curl` with https, OpenSSL will dump key information into the file.
I can then give that file to Wireshark (under the TCP protocol section in the settings) and Wireshark will do the rest of the decription.
Unforutanately, this only works for Wireshark, not termshark.

I tried adding `ENV SSLKEYLOGFILE=<some file>` in `Dockerfile.ztunnel` and then using those images in my ambient cluster, but nothing worked.
Maybe this has to do with the fact that Ztunnel using BoringSSL instead of OpenSSL.
Regardless, there has to be another way to do it.
If we go to John's [BoringSSL](https://github.com/howardjohn/boring) repo (this just has the Rust bindings), we can search of `keylog`.
`rg keylog`. A bunch of C and `.h` files show up, but if we search within the `boring` directory, we see that there is a
`pub fn set_keylog_callback<F>(&mut self, callback: F)` method.
Searching for `set_keylog_callback` in the whole repo, we see an example of how to use it in
`hyper-boring/src/test.rs`.

It would be ideal to just write to a file, but this setting is no global.
It is for a single connection? Not sure how it works.
Passing around a file handler would invole Arcs and Mutexes.
Too complicated.
Instead, I'm going to just print it to stdout with a small prefix.
That way, I can retrive it from `k logs` and pipe it into some filters.

I think before I continue down that path, it might be a good idea to look at what is happening in every step.
What's weird about these tests is that the server closes the connection with `TCP_CRR`.
Its hard to isolate behaviour because I don't think I can make it run only one transaction.
So I think I'm going to make a quick Python client and server that will do a TCP ping, but were the server closes the connection first.

Ok so I'm going to stop right now and just summarize what has happened.

* `netserver` seems to be waiting for a an ACK before sending its FIN, which is causing most of the slowdown.
* In the context of an H1.0 server, the server always sends the initial fin.
* From the cross mesh tests, this only happens when the server is in ambient.

As such, the most likely issue is that ACK delay in Ztunnels.

Things I want to do today:

* Decrypt the H2 messages using the keylog file. Just kinda curious what is happening behind TLS.
* Use a simple Python H1.0 server to replicate the issues on a smaller scale.
* Examine BoringSSL codebase of the keylog environment variable. Again, out of curiousity.
* See if there is quickack stuff in sidecar.

### Setting up a simple HTTP server and recording a transaction

First, we have to exec into the client and server **nodes** as above.
In the server, we create a small file using `echo hi > hi` and run `python3 -m http.server 35000`.
Make sure that the 35000 is open inthe k8 config.
In the client, we run `curl --http1.0 http://server:35000/hi` and we should get data back.

show call times, execution times, numbers in hexadecimal.
```
strace -tt -T -xx --output-file=... 
```
