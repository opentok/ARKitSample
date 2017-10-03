//
//  YCbCr-Shader.metal
//  ARKit Sample
//
//  Created by Roberto Perez Cubero on 26/09/2017.
//  Copyright © 2017 tokbox. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void YUVColorConversion(texture2d<uint, access::read> yTexture [[texture(0)]],
                               texture2d<uint, access::read> uTexture [[texture(1)]],
                               texture2d<uint, access::read> vTexture [[texture(2)]],
                               texture2d<float, access::write> outTexture [[texture(3)]],
                               uint2 gid [[thread_position_in_grid]])
{
    float3 colorOffset = float3(0, -0.5, -0.5);
    float3x3 colorMatrix = float3x3(
                                    float3(1, 1, 1),
                                    float3(0, -0.344, 1.770),
                                    float3(1.403, -0.714, 0)
                                    );

    uint2 uvCoords = uint2(gid.x / 2, gid.y / 2);
    
    float y = yTexture.read(gid).r / 255.0;
    float u = uTexture.read(uvCoords).r / 255.0;
    float v = vTexture.read(uvCoords).r / 255.0;

    float3 yuv = float3(y, u, v);

    float3 rgb = colorMatrix * (yuv + colorOffset);

    outTexture.write(float4(float3(rgb), 1.0), gid);
}
