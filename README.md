# nut2influx
pulls data from nut and pushes it into influx for UPS graphing

to install
```
cpanm Config::Simple Log::Log4perl InfluxDB::LineProtocol FindBin LWP::UserAgent
```

or use docker

# config

```
# ups details
[ups]
name=qnapups # ups name defined in ups.conf
model=su2200rtxl2ua # model name not really needed more important if you have multiple ups units
host=2.2.2.2 # host where nut server is
location=core
updateInterval=10

# influx db details
[influxDB]
host=1.1.1.1
port=8086
db=yourdbhere

```
