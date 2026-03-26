FROM 3proxy/3proxy:latest

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY start.sh /start.sh
RUN chmod a+x /start.sh


ENTRYPOINT ["/bin/sh","-c","/entrypoint.sh"]
