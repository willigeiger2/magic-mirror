# Objective
As web application that implements a "magic mirror" -- displays the local webcam, but with distortion and pixel mapping.

# Tech stack
Implement using Workers, Astro and WebGL.

# Core features
- A single page web application that takes the output of the webcam and renders it via WebGL using a 2d texture, so the rendered image can be modified programatically via a WebGL shader. You can implement spatial distortion either by modifiying the texture lookup coordinates in the shader, or by projecting the webcam image on to a grid of polygons whose vertices can be modified (in a geometry shader)?  

# Success criteria
The app is finished when there I can see the output of the webcam rendered in a view, and distort the image and change the pixel colors programmatically via a WebGL shader.