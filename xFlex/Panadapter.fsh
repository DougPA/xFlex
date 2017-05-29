//
// Panadapter Fragment Shader
//  xFlex
//

#version 330 core

uniform vec4 lineColor;

out vec4 outColor;

void main()
{
    // set the vertex color
    outColor = lineColor;
}
