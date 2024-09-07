import pickle
import numpy as np
from tensorflow import keras

def create_simple_model(input_shape, num_classes):
    model = keras.Sequential([
        keras.layers.Dense(64, activation='relu', input_shape=input_shape),
        keras.layers.Dense(32, activation='relu'),
        keras.layers.Dense(num_classes, activation='softmax')
    ])
    model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
    return model

def serialize_model(model):
    return pickle.dumps(model.get_weights())

def deserialize_model(serialized_model, model_architecture):
    weights = pickle.loads(serialized_model)
    model = model_architecture()
    model.set_weights(weights)
    return model

def aggregate_models(model_updates):
    aggregated_weights = []
    for weights_list_tuple in zip(*model_updates):
        aggregated_weights.append(
            np.array([np.array(w).mean(axis=0) for w in zip(*weights_list_tuple)])
        )
    return aggregated_weights

def main():
    # Example usage
    input_shape = (10,)
    num_classes = 2
    model = create_simple_model(input_shape, num_classes)
    
    serialized = serialize_model(model)
    deserialized = deserialize_model(serialized, lambda: create_simple_model(input_shape, num_classes))
    
    print("Original model summary:")
    model.summary()
    print("\nDeserialized model summary:")
    deserialized.summary()

if __name__ == "__main__":
    main()
