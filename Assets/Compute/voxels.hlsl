#define CHUNK_SIZE 80

struct Vertex {
    float3 position;
    float2 texcoord;
    float3 normal;
};

struct GeometryData {
    uint vertexCount;
    uint indexCount;
};

struct ChunkFeedback {
    uint vertexOffset;
    uint vertexCount;
    uint indexOffset;
    uint indexCount;
};

uint to1D(uint3 pos) {
    return pos.x + CHUNK_SIZE * (pos.y + CHUNK_SIZE * pos.z);
}

int to1D(int3 pos) {
    return pos.x + CHUNK_SIZE * (pos.y + CHUNK_SIZE * pos.z);
}

uint3 to3D(uint idx) {
    uint x = idx % CHUNK_SIZE;
    uint y = (idx / CHUNK_SIZE) % CHUNK_SIZE;
    uint z = idx / (CHUNK_SIZE * CHUNK_SIZE);
    
    return uint3(x, y, z);
}