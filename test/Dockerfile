FROM golang:1.19.3-buster

WORKDIR /app
COPY go.mod go.sum ./

RUN go mod download

COPY *.go ./

CMD [ "go", "test", "-count=1" ]