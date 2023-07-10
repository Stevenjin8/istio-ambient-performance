FROM networkstatic/netserver
RUN apt update -y && apt upgrade -y
RUN apt install -y netcat 
RUN apt install -y net-tools
RUN apt install -y tcpdump
RUN apt install -y netperf
RUN apt install -y less
RUN apt install -y ncat
EXPOSE 6789, 35000, 12865
COPY . .
ENTRYPOINT ./server-and-sleep.sh
