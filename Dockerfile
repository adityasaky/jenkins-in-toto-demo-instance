FROM jenkins/jenkins
ENV JENKINS_USER admin
ENV JENKINS_PASS password
ENV JENKINS_URL http://localhost:8080/
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false

ARG DOCKER_GROUP_ID

COPY plugins.txt /usr/share/jenkins/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/plugins.txt
COPY --chown=jenkins:jenkins jobs /var/jenkins_home/jobs

USER root

RUN groupadd -g $DOCKER_GROUP_ID docker

RUN apt-get update
RUN apt-get install -y apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
RUN apt-get update
RUN apt-get -y install docker-ce docker-ce-cli containerd.io
RUN usermod -aG docker jenkins

RUN apt-get install -y ruby-dev \
    build-essential \
    patch \
    zlib1g-dev \
    liblzma-dev
# we need an older version of jekyll because it's an older version of ruby
# ... which is because the base image is off Debian 9
RUN gem install pkg-config
RUN gem install nokogiri
RUN gem install jekyll -v 3.8.6
RUN gem install html-proofer -- --use-system-libraries=true

USER jenkins
