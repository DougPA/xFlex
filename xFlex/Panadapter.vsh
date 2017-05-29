//
// Panadapter Vertex Shader
//  xFlex
//

#version 330 core

layout (location = 0) in float yCoordinate;
layout (location = 1) in float xCoordinate;

uniform float delta;

float xCalculated;

void main()
{
    // calculate the x position
    xCalculated = -1 + (gl_VertexID * delta);

    // set the vertex position
    gl_Position = vec4(xCalculated, yCoordinate, 0.0, 1.0);
}
