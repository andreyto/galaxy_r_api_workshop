---
title: "Galaxy API R Client"
output:html_notebook
---
## The Galaxy container image

[README](https://github.com/bgruening/docker-galaxy-stable) contains detailed instructions
for controlling the container behavior.

In particular, [this section](https://github.com/bgruening/docker-galaxy-stable#Galaxys-config-settings)
decsribes default values of the admin account name, and the way to override it.
The default is:
```
GALAXY_CONFIG_ADMIN_USERS=admin@galaxy.org
```
and the password is `admin`.

You can override in this way any parameter from the [galaxy config file](https://github.com/galaxyproject/galaxy/blob/release_19.01/config/galaxy.yml.sample). 
This is not a container feature, this is a core Galaxy feature. When its config parser sees
an environment variable GALAXY_CONFIG_XXX, it will use its value to override the `galaxy.yaml` 
parameter `xxx`.

## Starting the container(s)

### Galaxy container

In a terminal on your *host*:

- `docker create -v /export --name galaxy-store bgruening/galaxy-stable /bin/true`
   This is a big image - will take a while to pull.
- `docker run -d -p 8080:80 -p 8800:8800 --rm --name galaxy --privileged --volumes-from galaxy-store bgruening/galaxy-stable`
  We use `--privileged` to auto-mount reference data through CVMFS (works on Windows?)
- Access container in Chrome at `localhost:8080`.
- Go to User->Preferences->Manage API key. Click Create a new key. 
  Copy the key somewhere to use in your client R session.

### R Studio Container

*You can also use some other R, but we installed a couple of necessary packages into our container*

In a terminal on your *host*:

- `docker run -v /home/rstudio/work2 --name rstudio-work sliders/rstudio-bcbiornaseq:v2 bash -c "chown -R rstudio. /home/rstudio/work2"`
  We created a volume owned by the user `rstudio` from the container
- `docker run -d -p 8787:8787 -e PASSWORD=bcbio -e ROOT=TRUE --volumes-from rstudio-work  sliders/rstudio-bcbiornaseq:v2`
- Access the R Studio Server at `localhost:8787`
- Login with user `rstudio` and password `bcbio`
- Open Tools->Terminal, and `cd work2 && git clone https://github.com/andreyto/galaxy_r_api_workshop.git`
- `sudo apt-get install python-pip`
- `sudo pip install parsec`
  This is a command-line (CLI) client for the remote Galaxy API. Calling it in a subprocess from a R session is 
  the easiest way to access Galaxy API from R since there are no R library bindings yet.

## Working in R

The API and bindings from different languages are described [here](https://galaxyproject.org/develop/api/)

### Define API key and URL

For now, this is just to record them somewhere to paste later in the terminal.

Use the host IP for the URL. This should be the IP of the real host interface that existed
before Docker has created a bunch of other interface. You can find it through your OS
Network Properties control panel, whatever it is. **Note**: `localhost` or `127.0.0.1` will
not work.

In your R console, do this:

```{r}
GAL_URL="http://10.25.117.136:8080"
GAL_API_KEY="73c730a5ac10f80d363bcd46b4ca28a8"
```

At first, we will still run commands from the terminal. You can wrap them in R `system()` function call
to program `parsec` CLI execution from R.

Run init and type your URL and key
```
parsec init
```
Download dataset by History Content API ID (get it by clicking on the dataset in Galaxy UI,
then clicking on the I icon under the expanded dataset panel).
```
parsec datasets download_dataset --file_path . 5969b1f7201f12ae
```

In your R console, do this:
```{r}
data = readRDS("Galaxy1-[copd_brushings_rnaseq_bcb.rds].binary")
data
```

You can play with other `parsec` commands, such as those that list datasets in histories. Look at
`parsec` GitHub README for the inspiration. `parsec` reflects most of the Galaxy API implemented 
by the Bioblend Python client library.

## Build Galaxy tool that works on our serialized BCBio SummarizedExperiment dataset

This is a very primitive prototype. We do not define a datatype and use default `binary` format for the `rds` file.

The primary objective is to demonstrate running a simple `Rscript` tool using our custom
Docker container to provide the dependencies.

We bind-mount several Galaxy config files and the tool itself into the container,  
and override the necessary locations through GALAXY_CONFIG_xxx environment variables passed
into the container. We do it in a fairly simplistic way just for demonstration.

In any case, the real-life tool code development is much better done through `Planemo` and
deployment through a local toolshed.

**Note**: To provide absolute host paths for bind-mounting, we use Unix shell command `pwd`,
which is not avalibale on Windows. You will have to edit the corresponding paths in the `docker run`
command if you are on Windows. Better still, activate Linux subsystem in Windows 10 and use Bash shell.

### In a terminal on your *host*:

`git clone https://github.com/andreyto/galaxy_r_api_workshop.git`

`docker stop galaxy`

```
  docker run -d --rm -p 8080:80 -p 8800:8800 --name galaxy --privileged --volumes-from galaxy-store \
  -v `pwd`/galaxy_r_api_workshop:/extra \
  -e GALAXY_CONFIG_TOOL_CONFIG_FILE="/extra/config/tool_conf.xml,config/tool_conf.xml.sample,config/shed_tool_conf.xml" \
  -e GALAXY_CONFIG_JOB_CONFIG_FILE="/extra/config/job_conf.xml" \
  bgruening/galaxy-stable \
  bash -c "supervisorctl stop docker; service docker stop; service docker start; startup"
```

### In your Chrome Web browser at the address `localhost:8080`:

- You should see a tool section on the left called R Tools. Under that, you should see a tool called "r_tool".
- Run the tool providing as input the `rds` file that you uploaded into Galaxy previously
- Once the output dataset status turns to finished (green), click on the eye icon to view the plot saved in the PDF format
- On your host, explore the content of the files that we bind-mounted from the cloned repository in order to get the 
  tool deployed and working. Notice how we configured the local runner in `config/job_conf.xml` to execute Docker containers,
  and how the tool's XML definition file declares the dependency as a container.

**Notes**: 
- When Docker inside the container pulls images, they do not get saved between container
  restarts. Expect to wait each time after a restart for the full pull when you run the tool
  for the first time.
- Sometimes, for reasons unclear, you can get an error status from the Galaxy tool, with the message
  saying that docker is not available (inside the container). This happens after the tool job was in
  a running (yellow) state for a while, and the Docker was pulling the container for the dependency.
  Apparently, Docker daemon dies inside the container.
  Open interactie shell inside the container using `docker exec -it galaxy bash` and start Docker there
  again with `service docker stop; service docker start`. Then, rerun the Galaxy tool.
