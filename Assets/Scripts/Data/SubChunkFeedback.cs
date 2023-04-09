using System.Runtime.InteropServices;

namespace Data
{
    // [StructLayout(LayoutKind.Explicit, Size = 16, Pack = 1)]
    public struct SubChunkFeedback {
        public uint vertexOffset;
        public uint vertexCount;
        public uint indexOffset;
        public uint indexCount;
    };
}