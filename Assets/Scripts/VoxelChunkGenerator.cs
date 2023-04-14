using Data;
using Native;
using Unity.Collections;
using Unity.Jobs;
using UnityEngine;
using UnityEngine.Rendering;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class VoxelChunkGenerator : MonoBehaviour
{
    private const int ChunkSize = 80;
    private const int WorkGroupSize = 8;
    private const int SubChunkSize = ChunkSize / WorkGroupSize;
    private const int VoxelCount = ChunkSize * ChunkSize * ChunkSize;

    public bool draw = true;
    public float frequency = 0.1f;
    public float amplitude = 1f;
    public Vector3 position;
    public Vector3 movementSpeed = new Vector3(5, 5, 5);
    
    public ComputeShader generateVoxelsComputeShader;
    public ComputeShader voxelizerComputeShader;
    public ComputeShader feedbackComputeShader;
    public Material drawMaterial;

    private NativeArray<int> _voxels;
    
    private ComputeBuffer _voxelBuffer;
    private ComputeBuffer _chunkFeedbackBuffer;
    private ComputeBuffer _subChunkFeedbackBuffer;
    private ComputeBuffer _vertexBuffer;
    private ComputeBuffer _indexBuffer;
    
    private int _generateVoxelsKernelId;
    private int _voxelizerKernelId;
    private int _feedbackKernelId;
    private Mesh _mesh;
    private MeshFilter _meshFilter;

    private readonly ChunkFeedback[] _chunkFeedback = new ChunkFeedback[1];

    private unsafe void Start()
    {
        _voxels = new NativeArray<int>(ChunkSize * ChunkSize * ChunkSize, Allocator.Persistent);
        
        // get mesh filter
        _meshFilter = GetComponent<MeshFilter>();
        
        // create mesh
        _mesh = new Mesh
        {
            name = "Voxel Chunk",
            indexFormat = IndexFormat.UInt32
        };
        _meshFilter.sharedMesh = _mesh;

        // get kernel ids
        _generateVoxelsKernelId = generateVoxelsComputeShader.FindKernel("CSMain");
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
        generateVoxelsComputeShader.SetBuffer(_generateVoxelsKernelId, "uVoxels", _voxelBuffer);
        
        voxelizerComputeShader.SetBuffer(_voxelizerKernelId, "uVertices", _vertexBuffer);
        voxelizerComputeShader.SetBuffer(_voxelizerKernelId, "uIndices", _indexBuffer);
        voxelizerComputeShader.SetBuffer(_voxelizerKernelId, "uVoxels", _voxelBuffer);
        voxelizerComputeShader.SetBuffer(_voxelizerKernelId, "uChunkFeedback", _subChunkFeedbackBuffer);
        
        feedbackComputeShader.SetBuffer(_feedbackKernelId, "uVoxels", _voxelBuffer);
        feedbackComputeShader.SetBuffer(_feedbackKernelId, "uFeedback", _chunkFeedbackBuffer);
        feedbackComputeShader.SetBuffer(_feedbackKernelId, "uChunkFeedback", _subChunkFeedbackBuffer);

        // copy material
        drawMaterial = new Material(drawMaterial);
        drawMaterial.SetBuffer("Vertices", _vertexBuffer);
        drawMaterial.SetBuffer("Indices", _indexBuffer);
    }

    private void Update()
    {
        MoveNoiseOrigin();
        
        // old and busted
        // GenerateRandomVoxelsCpu();
        
        // new hotness
        GenerateRandomVoxelsGpu();
        
        Compute();
        
        if (draw)
            DrawProcedural();
        
        Reset();
    }

    private void MoveNoiseOrigin()
    {
        position += movementSpeed * Time.deltaTime;
        
        generateVoxelsComputeShader.SetFloat("uFrequency", frequency);
        generateVoxelsComputeShader.SetFloat("uAmplitude", amplitude);
        generateVoxelsComputeShader.SetVector("uPosition", position);
    }

    private void Compute()
    {
        // dispatch feedback shader
        feedbackComputeShader.Dispatch(_feedbackKernelId, SubChunkSize, SubChunkSize, SubChunkSize);
        
        // read feedback data
        ReadFeedbackData();
        
        // dispatch voxelizer shader
        voxelizerComputeShader.Dispatch(_voxelizerKernelId, SubChunkSize, SubChunkSize, SubChunkSize);
    }

    private void ReadFeedbackData()
    {
        // read back data synchronously, this is a bottleneck
        _chunkFeedbackBuffer.GetData(_chunkFeedback);
        
        // reading async is much better, but you need to synchronize the vertex count when using DrawProcedural
        // AsyncGPUReadback.Request(_chunkFeedbackBuffer, request =>
        // {
        //     var data = request.GetData<ChunkFeedback>();
        //     _chunkFeedback[0] = data[0];
        // });
    }

    /// <summary>
    /// Create a mesh, get data from the buffers and assign it
    /// </summary>
    private void VisualiseChunkMesh()
    {
        var chunkFeedback = _chunkFeedback[0];

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

    private void DrawProcedural()
    {
        var chunkFeedback = _chunkFeedback[0];

        var bounds = new Bounds(Vector3.one * ChunkSize / 2f, Vector3.one * ChunkSize);
        
        Graphics.DrawProcedural(drawMaterial, bounds, MeshTopology.Triangles, (int)chunkFeedback.vertexCount);
    }

    private void Reset()
    {
        _chunkFeedback[0] = new ChunkFeedback();
        _chunkFeedbackBuffer.SetData(_chunkFeedback);
    }

    private void GenerateRandomVoxelsCpu()
    {
        var generateRandomVoxelsJob = new GenerateRandomVoxelsJob
        {
            Voxels = _voxels
        };
        
        generateRandomVoxelsJob.Schedule(_voxels.Length, ChunkSize).Complete();
        
        // set buffer data
        _voxelBuffer.SetData(_voxels);
    }
    
    private void GenerateRandomVoxelsGpu()
    {
        // dispatch shader
        generateVoxelsComputeShader.Dispatch(_generateVoxelsKernelId, SubChunkSize, SubChunkSize, SubChunkSize);
    }

    private void OnDestroy()
    {
        _voxelBuffer.Release();
        _chunkFeedbackBuffer.Release();
        _subChunkFeedbackBuffer.Release();
        _vertexBuffer.Release();
        _indexBuffer.Release();
        _voxels.Dispose();
        Destroy(_mesh);
    }
}
