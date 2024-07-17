application:
	./mvnw package -Dnative

docker:
	podman build -t greenfield-project .

all: application docker