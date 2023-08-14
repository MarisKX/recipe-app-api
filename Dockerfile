FROM python:3.9-alpine3.13
# This line specifies the base image to be used for the Docker container.
# In this case, it uses an image with Python 3.9 installed, based on the alpine3.13 lightweight Linux distribution.
# Alpine Linux is often used for Docker containers because of its small size.

LABEL maintener="mariskx"
# This line adds metadata to the image.
# It specifies that the maintainer (or author) of this Dockerfile or Docker image is "mariskx".

ENV PYTHONUNBUFFERED 1
# This sets an environment variable inside the Docker container.
# PYTHONUNBUFFERED set to 1 ensures that Python output is logged immediately without being buffered.
# This can be useful for viewing logs in real-time.

COPY ./requirements.txt /tmp/requirements.txt
# This line copies the requirements.txt file from the current directory
# on the host (where you're running the docker build command) to the /tmp directory inside the Docker image.
# This file usually lists the Python packages that need to be installed for the application.
COPY ./requirements.dev.txt /tmp/requirements.dev.txt

COPY ./app /app
# This line copies the app directory (and its contents) from the current directory on the host
# into an /app directory inside the Docker image.
# This is the application's source code or the main content of the application you're containerizing.

WORKDIR /app
# This sets the working directory inside the Docker container to /app.
# Any command that runs as part of the container will execute in this directory.
# Given that the application code was copied to this directory, it makes sense to set it as the working directory.

EXPOSE 8000
# This informs Docker that the container will be listening on port 8000.
# It's a way to document which ports are used, but it doesn't actually open the port.
# When you run the container, you'd typically map this container port to a port on the host.

ARG DEV=false
# It declares an argument named DEV.
# It sets a default value of false for this argument.
# If the user doesn't specify a value for DEV when building the Docker image, it will default to false.
# When building the Docker image, you can override the default value by using the --build-arg flag, for example:
# docker build --build-arg DEV=true -t your-image-name .

# This creates a new virtual environment for Python in the /py directory.
RUN python -m venv /py && \
    
    # It upgrades pip (Python's package manager) inside the virtual environment.
    /py/bin/pip install --upgrade pip && \

    # It uses the Alpine package manager (apk) to install the PostgreSQL client.
    # This is useful if your application interacts with a PostgreSQL database.
    apk add --update --no-cache postgresql-client && \

    # Some Python packages require compilation and need specific system libraries to build.
    # This command installs these dependencies.
    # The --virtual .tmp-build-deps means these packages are tagged with a label for easier removal later.
    apk add --update --no-cache --virtual .tmp-build-deps \
        # gcc libc-dev linux-headers postgresql-dev && \
        build-base postgresql-dev musl-dev && \

    # It installs Python packages specified in the requirements.txt file.
    /py/bin/pip install -r /tmp/requirements.txt && \

    # If the DEV build argument is set to true during the Docker build,
    # this will also install additional Python packages from requirements.dev.txt.
    if [ $DEV = "true" ] ; \
        then echo "--DEV BUILD--" && /py/bin/pip install -r /tmp/requirements.dev.txt ; \
    fi && \

    # Deletes the temporary build dependencies that were labeled as .tmp-build-deps earlier.
    apk del .tmp-build-deps && \

    # Removes any files in the /tmp directory to keep the Docker image clean.
    rm -rf /tmp && \

    # Adds a new user named django-user without a password and without creating a home directory.
    # This is often done for security reasons:
    # running services as a non-root user is a best practice to limit potential damage in case of vulnerabilities.
    adduser \
        --disabled-password \
        --no-create-home \
        django-user

ENV PATH="/py/bin:$PATH"
# ENV: This Dockerfile command is used to set environment variables.
# These variables will be available to processes running inside containers started from the resulting image.
# PATH="/py/bin:$PATH": This modifies the PATH environment variable to prepend /py/bin to it.
# As a result, the executables in the /py/bin directory (like python, pip, etc., from the virtual environment)
# will be available directly when you run commands.
# This ensures that the Python and pip binaries from our virtual environment are used by default over any other
# versions that might be installed.

USER django-user
# USER: The USER command in a Dockerfile changes the current user for any subsequent commands in the Dockerfile,
#and it also sets the default user when the container is run. If not specified, containers run as the root user by default.
# django-user: This specifies that the user named django-user (which was created in the previous steps you provided) will be
# the active user. Running processes as a non-root user in a container is a best practice for security.
# If there's a security vulnerability in the application, it will be more challenging for malicious actors to exploit
# the entire system as they would have limited permissions.