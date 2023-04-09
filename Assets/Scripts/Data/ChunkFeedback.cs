using System.Runtime.InteropServices;

namespace Data
{
    // [StructLayout(LayoutKind.Explicit, Size = 8, Pack = 1)]
    public struct ChunkFeedback {
        public uint vertexCount;
        public uint indexCount;
    };
}