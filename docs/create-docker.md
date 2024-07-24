# Create docker image

Instead of using the `./mvnw package -Dnative`-command, we use the `./mvnw install -Dnative -Dquarkus.native.container-build=true`-command. This will allow us to create an executable that will run in any container, no matter the operating system in which it was created.

./mvnw quarkus:add-extension -Dextensions='container-image-docker'