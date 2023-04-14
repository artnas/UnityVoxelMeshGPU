
#ifndef VOXEL_MESH_INFO
#define VOXEL_MESH_INFO

#include <Assets/Compute/voxels.hlsl>

StructuredBuffer<int> Indices;
StructuredBuffer<Vertex> Vertices;
 
void GetVertexData_float(float vertexId, out float3 position, out float2 texcoord, out float3 normal)
{
    const int index = Indices[round(vertexId)];
    position = Vertices[index].position;
    texcoord = Vertices[index].texcoord;
    normal = Vertices[index].normal;
}

#endif