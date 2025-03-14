ACKNOWLEGDEMENTS

Firstly, i'd like to give credit where credit is due - without the kind souls here on the internet i would have never managed to cobble together these lines of code into something workable.

Thus i thank :
Ben Golus , shader guru extraordinaire who patiently helped me and pointed me in a right direction
Art of Code, youtuber that explains the raymarcher magic
neginfinity, for solution to my problems with orthographic projections (for shadow casting under directional light)
Jasper Flick from Catlike coding for describing inner workings of shaders
sites Book of Shaders and ShaderToy for having a simply amazing shader demonstrations and explainers
Inigo Quilez for doing the hard work of making math/sdf functions much needed in raymarching.

DESCRIPTION

 This is aimed at those wanting to learn and create a raymarching shader without too much hassle of figuring out the structure or required functions etc. Some shader knowlege is required to understand what is going on, so doing prior research will go a long way.
Do note that these shaders are not perfect, there is certainly room for improvement and i may have wrongly used some shader API calls or have improperly written some of my own functions, so forgive me on that.

 This is composed of an opaque and a transparent shader versions.
Both shaders have same file structure, and almost same function names and function calls so one can do comparisons and (hopefully) learn from this.

 The shaders are designed to write to depth buffer and have a shadowcaster passes. For opaque shader, set to render at "geometry" queue, this means you should get a rendered "object" that is equal to normal meshes in scene. For transparent shader, set to write at "alpha test" queue, this is a bit different - if i remember correctly, transparent shaders usually don't write to depth buffer, but i tested and it appears to work so i decided to keep depth write. Similarly, casting shadows for transparent shader is kind of wrong, but again i saw it worked, same decision. :)

 For the transparent shader's shadowcaster pass, i decided to demonstrate "fake caustics" as an example and an exercise. As i wrote at the beginning, there is a lot going on and prior knowlege will help a lot.
