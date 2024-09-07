import numpy as np
from crypto_utils import generate_key_pair, sign_message, verify_signature
from model_utils import serialize_model, deserialize_model, aggregate_models

class SecureAggregator:
    def __init__(self):
        self.private_key, self.public_key = generate_key_pair()
        self.client_updates = {}

    def receive_client_update(self, client_id, serialized_update, signature, client_public_key):
        if verify_signature(client_public_key, serialized_update, signature):
            self.client_updates[client_id] = deserialize_model(serialized_update)
        else:
            raise ValueError(f"Invalid signature from client {client_id}")

    def aggregate_updates(self):
        if len(self.client_updates) < 2:
            raise ValueError("Not enough client updates to perform aggregation")
        
        model_updates = list(self.client_updates.values())
        aggregated_weights = aggregate_models(model_updates)
        
        return serialize_model(aggregated_weights)

    def send_aggregated_model(self, serialized_aggregated_model):
        signature = sign_message(self.private_key, serialized_aggregated_model)
        return serialized_aggregated_model, signature

def main():
    # Example usage
    aggregator = SecureAggregator()
    
    # Simulate receiving updates from clients
    for i in range(3):
        client_id = f"client_{i}"
        client_private_key, client_public_key = generate_key_pair()
        update = serialize_model([np.random.rand(5, 5), np.random.rand(5)])
        signature = sign_message(client_private_key, update)
        aggregator.receive_client_update(client_id, update, signature, client_public_key)
    
    # Perform secure aggregation
    aggregated_model = aggregator.aggregate_updates()
    
    # Send aggregated model
    serialized_aggregated_model, signature = aggregator.send_aggregated_model(aggregated_model)
    
    print("Secure aggregation completed")
    print(f"Aggregated model size: {len(serialized_aggregated_model)} bytes")
    print(f"Signature size: {len(signature)} bytes")

if __name__ == "__main__":
    main()
