# Create docker image

Instead of using the `./mvnw package -Dnative`-command, we use the `./mvnw install -Dnative --define quarkus.native.container-build=true --define quarkus.native.container-runtime=docker`-command. This will allow us to create an executable that will run in any container, no matter the operating system in which it was created.

After running this command, run the `./mvnw package -Dnative --define quarkus.native.container-build=true --define quarkus.native.container-runtime=docker`-command.
