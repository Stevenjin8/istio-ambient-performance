FROM networkstatic/netserver

# faster to iterate this way
RUN apt update -y && apt upgrade -y
RUN apt install -y netcat 
RUN apt install -y net-tools
RUN apt install -y tcpdump
RUN apt install -y netperf
RUN apt install -y less
RUN apt install -y ncat
RUN apt install -y termshark
RUN apt install -y python3
RUN apt install -y curl
RUN curl -OL https://github.com/fortio/fortio/releases/download/v1.17.0/fortio_1.17.0_amd64.deb
RUN dpkg -i fortio_1.17.0_amd64.deb

# tcp echo port
EXPOSE 6789
# tcp ping port (python)
EXPOSE 9999
# data port for netperf
EXPOSE 35000
# config port netperf 
EXPOSE 12865
# fortio server
EXPOSE 8080
EXPOSE 8078
EXPOSE 8079

COPY . .
ENTRYPOINT ./server-and-sleep.sh
