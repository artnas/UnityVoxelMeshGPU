using Data;
using UnityEngine;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class VoxelChunkGenerator : MonoBehaviour
{
    private const int ChunkSize = 80;
    private const int WorkGroupSize = 8;
    private const int SubChunkSize = ChunkSize / WorkGroupSize;
    private const int VoxelCount = ChunkSize * ChunkSize * ChunkSize;
    
    public ComputeShader voxelizerComputeShader;
    public ComputeShader feedbackComputeShader;
    
    private readonly int[] _voxels = new int[ChunkSize * ChunkSize * ChunkSize];
    
    private ComputeBuffer _voxelBuffer;
    private ComputeBuffer _chunkFeedbackBuffer;
    private ComputeBuffer _subChunkFeedbackBuffer;
    private ComputeBuffer _vertexBuffer;
    private ComputeBuffer _indexBuffer;
    
    private int _voxelizerKernelId;
    private int _feedbackKernelId;
    private Mesh _mesh;
    private MeshFilter _meshFilter;

    private unsafe void Start()
    {
        // get mesh filter
        _meshFilter = GetComponent<MeshFilter>();
        
        // create mesh
        _mesh = new Mesh
        {
            name = "Voxel Chunk"
        };
        _meshFilter.sharedMesh = _mesh;

        // get kernel ids
        _voxelizerKernelId = voxelizerComputeShader.FindKernel("CSMain");
        _feedbackKernelId = feedbackComputeShader.FindKernel("CSMain");
        
        // create buffers
        _voxelBuffer = new ComputeBuffer(_voxels.Length, sizeof(int));
        _chunkFeedbackBuffer = new ComputeBuffer(1, sizeof(ChunkFeedback));
        _chunkFeedbackBuffer.SetData(new []{ new ChunkFeedback() });
        _subChunkFeedbackBuffer = new ComputeBuffer(SubChunkSize * SubChunkSize * SubChunkSize, sizeof(SubChunkFeedback));
        _subChunkFeedbackBuffer.SetData(new SubChunkFeedback[SubChunkSize * SubChunkSize * SubChunkSize]);
        // max voxels * 4 vertices per face * 6 faces per voxel
        _vertexBuffer = new ComputeBuffer(VoxelCount * 4 * 6, sizeof(Vertex));
        // max voxels * 6 faces per voxel * 6 indices per face
        _indexBuffer = new ComputeBuffer(VoxelCount * 6 * 6, sizeof(int));
        
        // bind buffers
        voxelizerComputeShader.SetBuffer(_voxelizerKernelId, "uVertices", _vertexBuffer);
        voxelizerComputeShader.SetBuffer(_voxelizerKernelId, "uIndices", _indexBuffer);
        voxelizerComputeShader.SetBuffer(_voxelizerKernelId, "uVoxels", _voxelBuffer);
        voxelizerComputeShader.SetBuffer(_voxelizerKernelId, "uChunkFeedback", _subChunkFeedbackBuffer);
        feedbackComputeShader.SetBuffer(_feedbackKernelId, "uVoxels", _voxelBuffer);
        feedbackComputeShader.SetBuffer(_feedbackKernelId, "uFeedback", _chunkFeedbackBuffer);
        feedbackComputeShader.SetBuffer(_feedbackKernelId, "uChunkFeedback", _subChunkFeedbackBuffer);
    }

    private void Update()
    {
        GenerateRandomVoxels();
        Compute();
        ReadData();
        Reset();
    }

    private void Compute()
    {
        // dispatch compute shaders
        feedbackComputeShader.Dispatch(_feedbackKernelId, SubChunkSize, SubChunkSize, SubChunkSize);
        voxelizerComputeShader.Dispatch(_voxelizerKernelId, SubChunkSize, SubChunkSize, SubChunkSize);
    }

    private void ReadData()
    {
        // read back data
        var chunkFeedbackArray = new ChunkFeedback[1];
        _chunkFeedbackBuffer.GetData(chunkFeedbackArray);
        var chunkFeedback = chunkFeedbackArray[0];
        
        Debug.Log($"feedback: {chunkFeedback.vertexCount} vertices, {chunkFeedback.indexCount} indices");
        
        var subChunkFeedbackArray = new SubChunkFeedback[SubChunkSize * SubChunkSize * SubChunkSize];
        _subChunkFeedbackBuffer.GetData(subChunkFeedbackArray);

        for (var index = 0; index < subChunkFeedbackArray.Length; index++)
        {
            var subChunk = subChunkFeedbackArray[index];
            Debug.Log($"{index}: {subChunk.vertexCount} vertices, {subChunk.vertexOffset} offset, {subChunk.indexCount} indices, {subChunk.indexOffset} offset");
        }

        // get vertices and indices
        var vertices = new Vertex[chunkFeedback.vertexCount];
        var indices = new int[chunkFeedback.indexCount];
        
        _vertexBuffer.GetData(vertices, 0, 0, (int) chunkFeedback.vertexCount);
        _indexBuffer.GetData(indices, 0, 0, (int) chunkFeedback.indexCount);
        
        // create mesh data arrays 
        var meshVertices = new Vector3[chunkFeedback.vertexCount];
        var meshUVs = new Vector2[chunkFeedback.vertexCount];
        var meshNormals = new Vector3[chunkFeedback.vertexCount];
        
        for (var i = 0; i < chunkFeedback.vertexCount; i++)
        {
            var vertex = vertices[i];
            meshVertices[i] = vertex.Position;
            meshUVs[i] = vertex.UV;
            meshNormals[i] = vertex.Normal;
        }
        
        // assign data to mesh
        _mesh.Clear();
        _mesh.vertices = meshVertices;
        _mesh.uv = meshUVs;
        _mesh.normals = meshNormals;
        _mesh.SetIndices(indices, MeshTopology.Triangles, 0);
    }

    private void Reset()
    {
        var chunkFeedback = new ChunkFeedback[1];
        _chunkFeedbackBuffer.SetData(chunkFeedback);
    }

    private void GenerateRandomVoxels()
    {
        for (var i = 0; i < _voxels.Length; i++)
        {
            _voxels[i] = Random.Range(0, 2);
        }
        
        // set buffer data
        _voxelBuffer.SetData(_voxels);
    }

    private void OnDestroy()
    {
        _voxelBuffer.Release();
        _chunkFeedbackBuffer.Release();
        _subChunkFeedbackBuffer.Release();
        _vertexBuffer.Release();
        _indexBuffer.Release();
        Destroy(_mesh);
    }
}
