FROM ubuntu

ARG http_p
ARG terraform_version=0.9.2
ARG action=empty

ENV https_proxy $http_p
ENV http_proxy $http_p
ENV ACTION $action

# avoid user interaction (tzdata package - expect)
ENV DEBIAN_FRONTEND noninteractive

WORKDIR /k8s_kubespray

# required
COPY conf/ ./conf/
COPY kubespray_conf/ ./kubespray_conf/
COPY scripts/ ./scripts/
COPY \
    commissioning.conf.j2 \
    del.sh  \
    empty.sh \
    run.sh \
    ./
# additional
COPY ingress/ ./ingress/
COPY statefulsets/ ./statefulsets/

RUN apt-get update && \
    apt-get install -y \
        software-properties-common \
        wget \
        unzip \
        git \
        expect \
        vim \
        telnet \
        && \
    apt-add-repository -y ppa:ansible/ansible && \
    apt-get update && \
    apt-get install -y \
        ansible \
        && \
    apt-get clean

RUN wget https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip -P /tmp && \
    unzip /tmp/terraform_${terraform_version}_linux_amd64.zip -d /usr/local/bin/ && \
    rm -rf /tmp/terraform_${terraform_version}_linux_amd64.zip

ENV http_proxy ''
ENV https_proxy ''

ENTRYPOINT ./${ACTION}.sh