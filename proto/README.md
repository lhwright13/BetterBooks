<!-- Documentation for protobuf message definitions -->

# Protobuf Definitions

Shared gRPC definitions for communication between services.

## Generating Python stubs

Install the gRPC tools once:

```bash
pip install grpcio grpcio-tools
```

From the repository root run:

```bash
python -m grpc_tools.protoc -I proto \
    --python_out=proto --grpc_python_out=proto \
    proto/*.proto
```

This will generate `*_pb2.py` and `*_pb2_grpc.py` files next to the `.proto`
files which can be imported by the services.
