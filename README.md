# GPU voxel mesh generation and drawing in Unity HDRP

This is an experiment to generate a cubic voxel chunk mesh as efficiently as possible. This is insanely fast, meshing and drawing at around <b>400</b> FPS on my RTX 4090. The mesh generation itself is much faster than that, running at more than <b>1000</b> FPS with camera disabled.

This example uses a 3D noise library to generate voxel data. You can control frequency, amplitude and speed of the noise via inspector in Unity. This is also an example on how to use shader graph in conjunction with Graphics.DrawProcedural. This was made possible when Unity added VertexId node to shader graph.

https://user-images.githubusercontent.com/14143603/231909731-d0047d10-7ccd-440d-8c25-6b64d07315ad.mp4

## How it works

- generate voxels compute is run, voxel data (0/1) is generated using 3d noise
- feedback compute is run, this iterates all voxels and calculates the count of vertices and indices which will be required for the mesh
- voxelizer compute is run, this iterates all voxels and puts vertex and index data into the buffers
- the mesh is drawn with Graphics.DrawProcedural using data from index and vertex buffers

The mesh is generated on the GPU and is never read back to the CPU to create a Mesh object, that would be very slow by comparison (5 FPS).

## TODO

There is a lot to improve here, but it's a solid foundation

- Graphics.DrawProceduralIndirect instead of Graphics.DrawProcedural

## Credits

- [OpenGL voxelizer compute shaders by Demurzasty](https://github.com/demurzasty/HolyGrail)
- [GPU Noise by keijiro](https://github.com/keijiro/NoiseShader)
