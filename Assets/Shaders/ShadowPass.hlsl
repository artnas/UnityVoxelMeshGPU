
    // Pragmas
    #pragma target 4.5
    #pragma vertex Vert
    #pragma fragment Frag
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch
    #pragma multi_compile_instancing
    #pragma instancing_options renderinglayer

        // Keywords
        #pragma shader_feature _ _SURFACE_TYPE_TRANSPARENT
    #pragma shader_feature_local _BLENDMODE_OFF _BLENDMODE_ALPHA _BLENDMODE_ADD _BLENDMODE_PRE_MULTIPLY
    #pragma shader_feature_local _ _ADD_PRECOMPUTED_VELOCITY
    #pragma shader_feature_local _ _TRANSPARENT_WRITES_MOTION_VEC
    #pragma shader_feature_local _ _ENABLE_FOG_ON_TRANSPARENT
    // GraphKeywords: <None>

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/FragInputs.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPass.cs.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl" // Required to be include before we include properties as it define DECLARE_STACK_CB
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderGraphHeader.hlsl" // Need to be here for Gradient struct definition

    // --------------------------------------------------
    // Defines

    // Attribute
    #define ATTRIBUTES_NEED_NORMAL
    #define ATTRIBUTES_NEED_TANGENT

    #define HAVE_MESH_MODIFICATION


    #define SHADERPASS SHADERPASS_SHADOWS

    // Following two define are a workaround introduce in 10.1.x for RaytracingQualityNode
    // The ShaderGraph don't support correctly migration of this node as it serialize all the node data
    // in the json file making it impossible to uprgrade. Until we get a fix, we do a workaround here
    // to still allow us to rename the field and keyword of this node without breaking existing code.
    #ifdef RAYTRACING_SHADER_GRAPH_DEFAULT 
    #define RAYTRACING_SHADER_GRAPH_HIGH
    #endif

    #ifdef RAYTRACING_SHADER_GRAPH_RAYTRACED
    #define RAYTRACING_SHADER_GRAPH_LOW
    #endif
    // end

    #ifndef SHADER_UNLIT
    // We need isFrontFace when using double sided - it is not required for unlit as in case of unlit double sided only drive the cullmode
    // VARYINGS_NEED_CULLFACE can be define by VaryingsMeshToPS.FaceSign input if a IsFrontFace Node is included in the shader graph.
    #if defined(_DOUBLESIDED_ON) && !defined(VARYINGS_NEED_CULLFACE)
        #define VARYINGS_NEED_CULLFACE
    #endif
    #endif

        // Specific Material Define
    // Setup a define to say we are an unlit shader
    #define SHADER_UNLIT

    // Following Macro are only used by Unlit material
    #if defined(_ENABLE_SHADOW_MATTE) && SHADERPASS == SHADERPASS_FORWARD_UNLIT
    #define LIGHTLOOP_DISABLE_TILE_AND_CLUSTER
    #define HAS_LIGHTLOOP
    #endif
    // Caution: we can use the define SHADER_UNLIT onlit after the above Material include as it is the Unlit template who define it

    // To handle SSR on transparent correctly with a possibility to enable/disable it per framesettings
    // we should have a code like this:
    // if !defined(_DISABLE_SSR_TRANSPARENT)
    // pragma multi_compile _ WRITE_NORMAL_BUFFER
    // endif
    // i.e we enable the multicompile only if we can receive SSR or not, and then C# code drive
    // it based on if SSR transparent in frame settings and not (and stripper can strip it).
    // this is currently not possible with our current preprocessor as _DISABLE_SSR_TRANSPARENT is a keyword not a define
    // so instead we used this and chose to pay the extra cost of normal write even if SSR transaprent is disabled.
    // Ideally the shader graph generator should handle it but condition below can't be handle correctly for now.
    #if SHADERPASS == SHADERPASS_TRANSPARENT_DEPTH_PREPASS
    #if !defined(_DISABLE_SSR_TRANSPARENT) && !defined(SHADER_UNLIT)
        #define WRITE_NORMAL_BUFFER
    #endif
    #endif

    // NOTE: disabling de exposure usage on unlit shader graphs (caused by virtual texture constant buffer binding).
    // If we turn this on, in vulkan, virtual texture offsets are corrupted. It is likely caused by the stack
    // textures constant buffers, which utilize arrays. Something is happening to the reflection data of vulkan which completely displaces
    // the constant buffer. A bug is filed and is being looked at.
    #if defined(SHADER_API_VULKAN)
    #define DISABLE_UNLIT_DEEXPOSURE
    #endif

    #ifndef DEBUG_DISPLAY
        // In case of opaque we don't want to perform the alpha test, it is done in depth prepass and we use depth equal for ztest (setup from UI)
        // Don't do it with debug display mode as it is possible there is no depth prepass in this case
        #if !defined(_SURFACE_TYPE_TRANSPARENT)
            #if SHADERPASS == SHADERPASS_FORWARD
            #define SHADERPASS_FORWARD_BYPASS_ALPHA_TEST
            #elif SHADERPASS == SHADERPASS_GBUFFER
            #define SHADERPASS_GBUFFER_BYPASS_ALPHA_TEST
            #endif
        #endif
    #endif

    // Translate transparent motion vector define
    #if defined(_TRANSPARENT_WRITES_MOTION_VEC) && defined(_SURFACE_TYPE_TRANSPARENT)
        #define _WRITE_TRANSPARENT_MOTION_VECTOR
    #endif

    // Dots Instancing
    // DotsInstancingOptions: <None>

    // Various properties

    // HybridV1InjectedBuiltinProperties: <None>

    // -- Graph Properties
    CBUFFER_START(UnityPerMaterial)
    float4 _EmissionColor;
    float _UseShadowThreshold;
    float4 _DoubleSidedConstants;
    float _BlendMode;
    float _EnableBlendModePreserveSpecularLighting;
    CBUFFER_END

        // Object and Global properties

            // -- Property used by ScenePickingPass
            #ifdef SCENEPICKINGPASS
            float4 _SelectionID;
            #endif

    // -- Properties used by SceneSelectionPass
    #ifdef SCENESELECTIONPASS
    int _ObjectId;
    int _PassValue;
    #endif

    // Includes
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Debug/DebugDisplay.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Unlit/Unlit.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/BuiltinUtilities.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/MaterialUtilities.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderGraphFunctions.hlsl"

        // --------------------------------------------------
        // Structs and Packing

        struct AttributesMesh
    {
        float3 positionOS : POSITION;
        float3 normalOS : NORMAL;
        float4 tangentOS : TANGENT;
        #if UNITY_ANY_INSTANCING_ENABLED
        uint instanceID : INSTANCEID_SEMANTIC;
        #endif
    };
    struct VaryingsMeshToPS
    {
        float4 positionCS : SV_POSITION;
        #if UNITY_ANY_INSTANCING_ENABLED
        uint instanceID : CUSTOM_INSTANCE_ID;
        #endif
    };
    struct SurfaceDescriptionInputs
    {
    };
    struct VertexDescriptionInputs
    {
        float3 ObjectSpaceNormal;
        float3 ObjectSpaceTangent;
        float3 ObjectSpacePosition;
    };
    struct PackedVaryingsMeshToPS
    {
        float4 positionCS : SV_POSITION;
        #if UNITY_ANY_INSTANCING_ENABLED
        uint instanceID : CUSTOM_INSTANCE_ID;
        #endif
    };

        PackedVaryingsMeshToPS PackVaryingsMeshToPS(VaryingsMeshToPS input)
    {
        PackedVaryingsMeshToPS output;
        output.positionCS = input.positionCS;
        #if UNITY_ANY_INSTANCING_ENABLED
        output.instanceID = input.instanceID;
        #endif
        return output;
    }
    VaryingsMeshToPS UnpackVaryingsMeshToPS(PackedVaryingsMeshToPS input)
    {
        VaryingsMeshToPS output;
        output.positionCS = input.positionCS;
        #if UNITY_ANY_INSTANCING_ENABLED
        output.instanceID = input.instanceID;
        #endif
        return output;
    }

    // --------------------------------------------------
    // Graph


    // Graph Functions
    // GraphFunctions: <None>

    // Graph Vertex
    struct VertexDescription
    {
        float3 Position;
        float3 Normal;
        float3 Tangent;
    };

    VertexDescription VertexDescriptionFunction(VertexDescriptionInputs IN)
    {
        VertexDescription description = (VertexDescription)0;
        description.Position = IN.ObjectSpacePosition;
        description.Normal = IN.ObjectSpaceNormal;
        description.Tangent = IN.ObjectSpaceTangent;
        return description;
    }

    // Graph Pixel
    struct SurfaceDescription
    {
        float Alpha;
    };

    SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
    {
        SurfaceDescription surface = (SurfaceDescription)0;
        surface.Alpha = 1;
        return surface;
    }

    // --------------------------------------------------
    // Build Graph Inputs


    VertexDescriptionInputs AttributesMeshToVertexDescriptionInputs(AttributesMesh input)
    {
        VertexDescriptionInputs output;
        ZERO_INITIALIZE(VertexDescriptionInputs, output);

        output.ObjectSpaceNormal = input.normalOS;
        output.ObjectSpaceTangent = input.tangentOS.xyz;
        output.ObjectSpacePosition = input.positionOS;

        return output;
    }

    AttributesMesh ApplyMeshModification(AttributesMesh input, float3 timeParameters)
    {
        // build graph inputs
        VertexDescriptionInputs vertexDescriptionInputs = AttributesMeshToVertexDescriptionInputs(input);
        // Override time paramters with used one (This is required to correctly handle motion vector for vertex animation based on time)

        // evaluate vertex graph
        VertexDescription vertexDescription = VertexDescriptionFunction(vertexDescriptionInputs);

        // copy graph output to the results
        input.positionOS = vertexDescription.Position;
        input.normalOS = vertexDescription.Normal;
        input.tangentOS.xyz = vertexDescription.Tangent;

        return input;
    }
        FragInputs BuildFragInputs(VaryingsMeshToPS input)
    {
        FragInputs output;
        ZERO_INITIALIZE(FragInputs, output);

        // Init to some default value to make the computer quiet (else it output 'divide by zero' warning even if value is not used).
        // TODO: this is a really poor workaround, but the variable is used in a bunch of places
        // to compute normals which are then passed on elsewhere to compute other values...
        output.tangentToWorld = k_identity3x3;
        output.positionSS = input.positionCS;       // input.positionCS is SV_Position


        return output;
    }

    SurfaceDescriptionInputs FragInputsToSurfaceDescriptionInputs(FragInputs input, float3 viewWS)
    {
        SurfaceDescriptionInputs output;
        ZERO_INITIALIZE(SurfaceDescriptionInputs, output);

        #if defined(SHADER_STAGE_RAY_TRACING)
        #else
        #endif

        return output;
    }

    // existing HDRP code uses the combined function to go directly from packed to frag inputs
    FragInputs UnpackVaryingsMeshToFragInputs(PackedVaryingsMeshToPS input)
    {
        UNITY_SETUP_INSTANCE_ID(input);
        VaryingsMeshToPS unpacked = UnpackVaryingsMeshToPS(input);
        return BuildFragInputs(unpacked);
    }

    // --------------------------------------------------
    // Build Surface Data (Specific Material)

    void BuildSurfaceData(FragInputs fragInputs, inout SurfaceDescription surfaceDescription, float3 V, PositionInputs posInput, out SurfaceData surfaceData)
    {
        // setup defaults -- these are used if the graph doesn't output a value
        ZERO_INITIALIZE(SurfaceData, surfaceData);

        // copy across graph values, if defined

        #ifdef WRITE_NORMAL_BUFFER
        // When we need to export the normal (in the depth prepass, we write the geometry one)
        surfaceData.normalWS = fragInputs.tangentToWorld[2];
        #endif

        #if defined(DEBUG_DISPLAY)
        if (_DebugMipMapMode != DEBUGMIPMAPMODE_NONE)
        {
            // TODO
        }
        #endif

        #if defined(_ENABLE_SHADOW_MATTE) && SHADERPASS == SHADERPASS_FORWARD_UNLIT
            HDShadowContext shadowContext = InitShadowContext();
            float shadow;
            float3 shadow3;
            // We need to recompute some coordinate not computed by default for shadow matte
            posInput = GetPositionInput(fragInputs.positionSS.xy, _ScreenSize.zw, fragInputs.positionSS.z, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
            float3 upWS = normalize(fragInputs.tangentToWorld[1]);
            uint renderingLayers = GetMeshRenderingLightLayer();
            ShadowLoopMin(shadowContext, posInput, upWS, asuint(_ShadowMatteFilter), renderingLayers, shadow3);
            shadow = dot(shadow3, float3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0));

            float4 shadowColor = (1.0 - shadow) * surfaceDescription.ShadowTint.rgba;
            float  localAlpha = saturate(shadowColor.a + surfaceDescription.Alpha);

            // Keep the nested lerp
            // With no Color (bsdfData.color.rgb, bsdfData.color.a == 0.0f), just use ShadowColor*Color to avoid a ring of "white" around the shadow
            // And mix color to consider the Color & ShadowColor alpha (from texture or/and color picker)
            #ifdef _SURFACE_TYPE_TRANSPARENT
                surfaceData.color = lerp(shadowColor.rgb * surfaceData.color, lerp(lerp(shadowColor.rgb, surfaceData.color, 1.0 - surfaceDescription.ShadowTint.a), surfaceData.color, shadow), surfaceDescription.Alpha);
            #else
                surfaceData.color = lerp(lerp(shadowColor.rgb, surfaceData.color, 1.0 - surfaceDescription.ShadowTint.a), surfaceData.color, shadow);
            #endif
            localAlpha = ApplyBlendMode(surfaceData.color, localAlpha).a;

            surfaceDescription.Alpha = localAlpha;
        #endif
    }

    // --------------------------------------------------
    // Get Surface And BuiltinData

    void GetSurfaceAndBuiltinData(FragInputs fragInputs, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData RAY_TRACING_OPTIONAL_PARAMETERS)
    {
        // Don't dither if displaced tessellation (we're fading out the displacement instead to match the next LOD)
        #if !defined(SHADER_STAGE_RAY_TRACING) && !defined(_TESSELLATION_DISPLACEMENT)
        #ifdef LOD_FADE_CROSSFADE // enable dithering LOD transition if user select CrossFade transition in LOD group
        LODDitheringTransition(ComputeFadeMaskSeed(V, posInput.positionSS), unity_LODFade.x);
        #endif
        #endif

        #ifndef SHADER_UNLIT
        #ifdef _DOUBLESIDED_ON
            float3 doubleSidedConstants = _DoubleSidedConstants.xyz;
        #else
            float3 doubleSidedConstants = float3(1.0, 1.0, 1.0);
        #endif

        ApplyDoubleSidedFlipOrMirror(fragInputs, doubleSidedConstants); // Apply double sided flip on the vertex normal
        #endif // SHADER_UNLIT

        SurfaceDescriptionInputs surfaceDescriptionInputs = FragInputsToSurfaceDescriptionInputs(fragInputs, V);
        SurfaceDescription surfaceDescription = SurfaceDescriptionFunction(surfaceDescriptionInputs);

        // Perform alpha test very early to save performance (a killed pixel will not sample textures)
        // TODO: split graph evaluation to grab just alpha dependencies first? tricky..
        #ifdef _ALPHATEST_ON
            float alphaCutoff = surfaceDescription.AlphaClipThreshold;
            #if SHADERPASS == SHADERPASS_TRANSPARENT_DEPTH_PREPASS
            // The TransparentDepthPrepass is also used with SSR transparent.
            // If an artists enable transaprent SSR but not the TransparentDepthPrepass itself, then we use AlphaClipThreshold
            // otherwise if TransparentDepthPrepass is enabled we use AlphaClipThresholdDepthPrepass
            #elif SHADERPASS == SHADERPASS_TRANSPARENT_DEPTH_POSTPASS
            // DepthPostpass always use its own alpha threshold
            alphaCutoff = surfaceDescription.AlphaClipThresholdDepthPostpass;
            #elif (SHADERPASS == SHADERPASS_SHADOWS) || (SHADERPASS == SHADERPASS_RAYTRACING_VISIBILITY)
            // If use shadow threshold isn't enable we don't allow any test
            #endif

            GENERIC_ALPHA_TEST(surfaceDescription.Alpha, alphaCutoff);
        #endif

        #if !defined(SHADER_STAGE_RAY_TRACING) && _DEPTHOFFSET_ON
        ApplyDepthOffsetPositionInput(V, surfaceDescription.DepthOffset, GetViewForwardDir(), GetWorldToHClipMatrix(), posInput);
        #endif

        #ifndef SHADER_UNLIT
        float3 bentNormalWS;
        BuildSurfaceData(fragInputs, surfaceDescription, V, posInput, surfaceData, bentNormalWS);

        // Builtin Data
        // For back lighting we use the oposite vertex normal
        InitBuiltinData(posInput, surfaceDescription.Alpha, bentNormalWS, -fragInputs.tangentToWorld[2], fragInputs.texCoord1, fragInputs.texCoord2, builtinData);

        #else
        BuildSurfaceData(fragInputs, surfaceDescription, V, posInput, surfaceData);

        ZERO_INITIALIZE(BuiltinData, builtinData); // No call to InitBuiltinData as we don't have any lighting
        builtinData.opacity = surfaceDescription.Alpha;

        #if defined(DEBUG_DISPLAY)
        // Light Layers are currently not used for the Unlit shader (because it is not lit)
        // But Unlit objects do cast shadows according to their rendering layer mask, which is what we want to
        // display in the light layers visualization mode, therefore we need the renderingLayers
        builtinData.renderingLayers = GetMeshRenderingLightLayer();
    #endif

    #endif // SHADER_UNLIT

    #ifdef _ALPHATEST_ON
        // Used for sharpening by alpha to mask - Alpha to covertage is only used with depth only and forward pass (no shadow pass, no transparent pass)
        builtinData.alphaClipTreshold = alphaCutoff;
    #endif

    // override sampleBakedGI - not used by Unlit


    // Note this will not fully work on transparent surfaces (can check with _SURFACE_TYPE_TRANSPARENT define)
    // We will always overwrite vt feeback with the nearest. So behind transparent surfaces vt will not be resolved
    // This is a limitation of the current MRT approach.

    #if _DEPTHOFFSET_ON
    builtinData.depthOffset = surfaceDescription.DepthOffset;
    #endif

    // TODO: We should generate distortion / distortionBlur for non distortion pass
    #if (SHADERPASS == SHADERPASS_DISTORTION)
    builtinData.distortion = surfaceDescription.Distortion;
    builtinData.distortionBlur = surfaceDescription.DistortionBlur;
    #endif

    #ifndef SHADER_UNLIT
    // PostInitBuiltinData call ApplyDebugToBuiltinData
    PostInitBuiltinData(V, posInput, surfaceData, builtinData);
    #else
    ApplyDebugToBuiltinData(builtinData);
    #endif

    RAY_TRACING_OPTIONAL_ALPHA_TEST_PASS
}

// --------------------------------------------------
// Main

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPassDepthOnly.hlsl"