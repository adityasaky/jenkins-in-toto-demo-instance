FROM jenkins/jenkins
ENV JENKINS_USER admin
ENV JENKINS_PASS password
ENV JENKINS_URL http://localhost:8080/
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false
COPY plugins.txt /usr/share/jenkins/plugins.txt
RUN /usr/local/bin/install-plugins.sh < /usr/share/jenkins/plugins.txt
COPY --chown=jenkins:jenkins jobs /var/jenkins_home/jobs