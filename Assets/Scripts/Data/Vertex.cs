using System.Runtime.InteropServices;
using UnityEngine;

namespace Data
{
    [StructLayout(LayoutKind.Sequential)]
    public struct Vertex
    {
        public Vector3 Position; // 12
        public Vector2 UV; // 8
        public Vector3 Normal; // 12
    }
}