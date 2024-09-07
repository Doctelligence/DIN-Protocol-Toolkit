import ipfshttpclient

def connect_to_ipfs(host='127.0.0.1', port=5001):
    return ipfshttpclient.connect(f'/ip4/{host}/tcp/{port}')

def add_to_ipfs(client, data):
    return client.add_json(data)

def get_from_ipfs(client, cid):
    return client.get_json(cid)

def main():
    # Example usage
    client = connect_to_ipfs()
    
    # Add data to IPFS
    data = {"key": "value"}
    cid = add_to_ipfs(client, data)
    print(f"Added data to IPFS with CID: {cid}")
    
    # Retrieve data from IPFS
    retrieved_data = get_from_ipfs(client, cid)
    print(f"Retrieved data from IPFS: {retrieved_data}")

if __name__ == "__main__":
    main()
