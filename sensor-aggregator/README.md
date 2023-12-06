# Demo

Source code can be found from https://github.com/open-cluster-management-io/addon-contrib/tree/main/device-addon

1. Run `./deploy.sh` to prepare demo env, this command will
    - Create a kind cluster
    - Install the OCM in this cluster
    - Install an OP-CUA server to simulate an OP-CUA device
2. Run `./demo.sh` to start the demo
3. Use a MQTT client to receive the device data, e.g.
   ```bash
   mosquitto_sub -h 127.0.0.1 -p 1883 -t devices/+/data/+
   ```
4. (Optional) Integrate with [thingsboard](https://thingsboard.io/)
    - Go to https://demo.thingsboard.io/ and create a thingsboard gateway (refer to this [doc](https://thingsboard.io/docs/iot-gateway/getting-started/))
    - Start the thingsboard on your local cluster
      ```bash
      docker run -it -v ~/.tb-gateway/logs:/thingsboard_gateway/logs \
        -v ~/.tb-gateway/extensions:/thingsboard_gateway/extensions \
        -v ~/.tb-gateway/config:/thingsboard_gateway/config \
        --name tb-gateway \
        --restart always thingsboard/tb-gateway
      ```
    - Copy the thingsboard config file `./thingsboard/mqtt.json` to the `${HOME}/.tb-gateway/config`
    - Restart the thingsboard
      ```bash
      docker stop tb-gateway
      docker start tb-gateway
      ```
