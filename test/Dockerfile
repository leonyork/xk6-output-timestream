FROM golang:1.20.5-buster

WORKDIR /app
COPY go.mod go.sum ./

RUN go mod download

COPY *.go fixtures.json ./

CMD [ "go", "test", "-count=1" ]
