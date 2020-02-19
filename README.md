This demo combines the latest version of the `in-toto` Jenkins plugin, which is
capable of generating `in-toto` link attestations for steps performed in a
Jenkins pipeline.

The `Dockerfile` builds a Jenkins container with access to the host's Docker
socket and permissions to build and run containers. The container has the
`in-toto` plugin pre-installed and has a demo pipeline with the following steps:
    - `clone` - this step clones a demo project from GitHub
    - `jekyll-build` - this step builds the Jekyll site that was downloaded
    - `html-linter` - this step runs an HTML linter on the Jekyll site
    - `docker-build` - this step creates a Docker container for the site -\
        henceforth known as the child image

### The story behind this app

To build this app, a team of three people (Alice, Bob and Carl) get together to
set everything up. Alice, is the project owner and she trusts Bob -- the
frontend guy --- to make a release of the webapp using *git*. As you may have
guessed it, Carl is a backend builder, and he will be in charge of scheduling a
build using *jekyll*, ensuring the quality of the resulting build using
*htmlproofer* and finally putting everything inside of an nginx container using
*docker*.

Alice will then create a policy about all of these operations and will instruct
her friends to follow them to the letter. To do this, she will use an in-toto
*layout* (which is already provided and signed, for the sake of this demo).

In order to ensure compliance, Bob and Carl will carry out their operations,
and they will use in-toto tools to create pieces of *link metadata* (i.e..,
software bills of materials) to prove that they did what they were meant to do.

A deployment team (or Alice herself) can use this policy in the *root.layout*
file, plus all the conjoined links to verify that the resulting webapp, was
built properly, and that everything was followed to the letter.

## Running the demo:

This demo files are all located under the "workbench" directory. In it, you will
find three directories:

- `keys`: where all the cryptographic keys are held (in the real world, these
  should be kept in a safer spot)
- `metadata`: a fallback repository with a verifiable set of metadata for this
  repository (in case you need to fall back into a valid verification state)
- `in-toto-demo-jenkins`: this repository is where the jenkins job files are set,
  and it's only relevant in case you want to run the jenkins instance
  (explained below)

The demo will be separated in three main "acts":

1. Manually running the pipeline and verifying it.
2. The compromise: acting as if somebody has access to the Docker Hub account
   and is able to push a malicious build
3. Showing the Jenkins setup, so that you can see how this all can be.

We will dive into how to carry out these three acts next.

### Manually running the pipeline and verifying it

The pipeline is to be run in the powershell, and we assume that the starting
directory is workbench. In this act, we are both Bob and Carl, and we will be
building the webapp manually and creating signed attestations using in-toto.

This demo will require the use of the in-toto CLI tool. While some are common
for UNIX-like and Windows systems, where they differ, both are provided
separately.

#### Checking out the code as Bob

You are now Bob, and you will sign off a release of the latest in-toto webapp.
To do this, you will use the following incantation:

```bash
in-toto-run -n clone -k keys/bob --products demo-project-jekyll -- git clone https://github.com/in-toto/demo-project-jekyll
```

On a Windows system, the following command must be run in `powershell`.

```powershell
in-toto-run -n clone -k keys\bob --products demo-project-jekyll -- git clone https://github.com/in-toto/demo-project-jekyll
```

This will wrap git clone and capture all the *artifacts* that were created as
products. Here, you can showcase how a software bill of materials (i.e., the
in-toto *link metadata*) looks by executing:

```
cat clone*.link
```

And showing the json object containing hashes of all the webapp files, as well
as a digital signature over all of these. Great! we have created our first link.

Before we move on though, and in order to keep the metadata tidy, we will
create a directory called "verification" and move our link metadata there:

```
mkdir verification
mv clone*.link verification
```

#### Building the webapp as Carl

Now, let's take Carl's seat and build the webapp. First, let's change to the
application directory so we can build it:

```
cd demo-project-jekyll
````

In there, you probably recognize a couple of files required to build and
containerize the application. This time, we will separate everything, just for
the sake of demonstration. We will carry out the build first and create a bill
of materials for it:

```bash
in-toto-run -n jekyll-build --materials . --products . --key ../keys/carl -- jekyll build
```

In `powershell`:

```powershell
in-toto-run -n jekyll-build --materials . --products . --key ..\keys\carl -- jekyll.bat build
```

Once this command is done executing, you will find a new piece of link metadata
under jekyll-build.xxxx.link . You may inspect it (and notice is a little bit
more verbose than the clone one) or you can simply move it to the verification
directory.

```
mv jekyll-build.*.link ..\verification
```

#### Linting and building the container

The next steps are pretty similar so we can fast forward to them (or use the
cached metadata for it). We will execute the following commands to both run a
linter over our generated html files (because our webapp has high-compliance
standards) and then put everything in a docker container):

```bash
in-toto-run -n html-linter --materials . --products . --key ../keys/carl -- htmlproofer _site/*
in-toto-run -n docker-build --materials . --products . --key ../keys/carl -- docker build -t jekyll-demo --iidfile docker_container_id .
```

This differs slightly on Windows systems. Run the following commands in
`powershell`:

```powershell
in-toto-run -n html-linter --materials . --products . --key ..\keys\carl -- htmlproofer.bat _site/*
in-toto-run -n docker-build --materials . --products . --key ..\keys\carl -- docker build -t jekyll-demo --iidfile docker_container_id .
```

```
mv *.link ..\verification
```

Notice the flags to docker build (we will need these to tie the built image
to the build when verifying).

#### Verifying

Before running our container, we want to make sure everything went as expected,
so we will run verification over all the metadata we collected. To perform
verification, we will fetch Alice's layout from the metadata directory and then
run in-toto's verification routine

```bash
cd ../verification
cp ../metadata/root.layout .
in-toto-verify -v -l root.layout -k ../keys/alice.pub
```

In `powershell`:

```powershell
cd ..\verification
cp ..\metadata\root.layout .
in-toto-verify -v -l root.layout -k ..\keys\alice.pub
```

You may see some warnings about command alignment, they are expected, don't
worry. However, you should *not* see any errors come out and the last line
should say "the software passed all verification"

Now that we know we can trust the image, we can run the container and see
what's in it.

```
docker run -p 80:4000 jekyll-demo
```

Now, let's try and see how things go if somebody broke into Docker Hub.

### The compromise:

In order to compromise the webapp, you just need to execute the following
commands:

```bash
cd ../demo-project-jekyll
git checkout compromise # this is a malicious branch
docker build -t demo-project-jekyll .
```

On a Windows machine:

```powershell
cd ..\demo-project-jekyll
git checkout compromise # this is a malicious branch
docker build -t demo-project-jekyll .
```

This will overwrite the existing copy of the container with a malicious
version. However, we can still run verification, and see what's going on:

```bash
cd ../metadata
in-toto-verify -v -l root.layout -k ../keys.alice.pub
```

On a Windows machine, run the following commands in `powershell`:

```powershell
cd ..\metadata
in-toto-verify -v -l root.layout -k ..\keys.alice.pub
```

This time, you should see that in-toto detected that the container id was
tampered with and prints an error telling you as much.

### Running everything in Jenkins

The Jenkins plugin is a little heavy. We have pre-fetched a docker container
with jenkins preinstalled and the in-toto plugin inside. To launch the container
you will need to do the following after cloning this repository:

```
cd jenkins-in-toto-demo-instance # this is where all the jenkins jobs are held
docker run -p 8080:8080 --user root -v $PWD/keys:/keys -v $PWD/jobs:/var/jenkins-home/jobs -v //var/run/docker.sock:/var/run/docker.sock --rm -d intoto/jenkins-in-toto 
```

Now, you can launch edge and go to localhost:8080. In there, you should find
the same demo pipeline. You can click on it. If you click on settings, you will
find the pipeline script (with the in-toto keywords to enable artifact
tracking). You can also execute the pipeline by clicking on "build now". You
can click the log and see how the steps are carried out and how the in-toto
metadata is generated along the way.

```
ls jobs\in-toto-demo-pipeline\workspace\*.link
```

You will see these familiar metadata files, which you can likewise verify once
jenkins is done running. However, you will need a small variation of the layout
(to account for the location of the files where jenkins is generating them),
which is under jenkins-in-toto-demo-instance\metadata\root.layout.signed.
Verifying it works in the exact same way.

### Cleaning up:

In order to reset everything to its starting stage, you will have to do the
following:

- keys\: you didn't touch keys, so there's nothing to do there.
- metadata\: you can:
    1. `cd metadata`
    2. `git clean -xdff`
- jenkins-in-toto-demo-instance\:
    1. `cd jenkins-in-toto-demo-instance`
    2. `git clean -xdff`
    3. `git reset --hard HEAD`
- You can safely remove the demo-project-jekyll repository:
    1. `rm demo-project-jekyll -Recurse -Force`

Now you should be ready to start over.
