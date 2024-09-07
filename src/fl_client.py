import numpy as np
from crypto_utils import hash_data, sign_message, verify_signature
from model_utils import serialize_model, deserialize_model

class FederatedLearningClient:
    def __init__(self, client_id, private_key, public_key):
        self.client_id = client_id
        self.private_key = private_key
        self.public_key = public_key
        self.model = None

    def receive_global_model(self, serialized_model, signature, server_public_key):
        if verify_signature(server_public_key, serialized_model, signature):
            self.model = deserialize_model(serialized_model)
        else:
            raise ValueError("Invalid model signature")

    def train_local_model(self, local_data, epochs=1):
        # Simplified local training
        for _ in range(epochs):
            for batch in local_data:
                self.model.train_on_batch(batch)

    def compute_update(self):
        return serialize_model(self.model)

    def send_update(self, serialized_update):
        signature = sign_message(self.private_key, serialized_update)
        return self.client_id, serialized_update, signature

def main():
    # Example usage
    client = FederatedLearningClient("client1", private_key, public_key)
    client.receive_global_model(global_model, signature, server_public_key)
    client.train_local_model(local_data)
    update = client.compute_update()
    client_id, serialized_update, signature = client.send_update(update)

if __name__ == "__main__":
    main()
