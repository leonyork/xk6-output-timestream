FROM golang:1.19.4-buster

WORKDIR /app
COPY go.mod go.sum ./

RUN go mod download

COPY *.go fixtures.json ./

CMD [ "go", "test", "-count=1" ]