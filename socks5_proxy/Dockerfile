FROM 3proxy/3proxy:latest

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh


ENTRYPOINT ["/bin/sh","-c","/entrypoint.sh"]
