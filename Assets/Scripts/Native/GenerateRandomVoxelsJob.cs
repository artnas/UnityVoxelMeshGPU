using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;

namespace Native
{
    [BurstCompile]
    public struct GenerateRandomVoxelsJob : IJobParallelFor
    {
        public NativeArray<int> Voxels;

        public void Execute(int index)
        {
            Voxels[index] = Random.CreateFromIndex((uint)index).NextInt(0, 2);
        }
    }
}