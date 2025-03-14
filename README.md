ACKNOWLEDGEMENTS

Firstly, i'd like to give credit where credit is due - without the kind souls here on the internet i would have never managed to cobble together these lines of code into something workable.

Thus i thank :
- Ben Golus , shader guru extraordinaire who patiently helped me and pointed me in a right direction
- Art of Code, youtuber that explains the raymarcher magic, also present on shadertoy site
- neginfinity, for solution to my problems with orthographic projections (shadow casting under directional light)
- user "SCRN-VRC" on github for "cheap realtime ambient occlusion" code - ingenious idea
- Jasper Flick from Catlike coding for describing inner workings of shaders
- sites Book of Shaders and ShaderToy for having a simply amazing shader demonstrations and explainers
- Inigo Quilez for doing the hard work of making math/sdf functions much needed in raymarching
- user "dust" on shadertoy site whose code for raymarching function got me out of the hot water

Where possible, i have added comments in code relating the used function to the sources created by above authors.
Since this is my pet project i intermittently worked on, i most likely managed to loose track of all authors whose published code i used to construct my own files.
If i recall any more of them, i'll add them to the above list and/or mention in shader code where applicable.

DESCRIPTION

 This is aimed at those wanting to learn and create a raymarching shader without too much hassle of figuring out the structure or required functions etc. Some shader knowlege is required to understand what is going on, so doing prior research will go a long way.
Do note that these shaders are not perfect, there is certainly room for improvement and i may have wrongly used some shader API calls or have improperly written some of my own functions, so forgive me on that.

 This is composed of an opaque and a transparent shader versions.
Both shaders have same file structure, and almost same function names and function calls so one can do comparisons and (hopefully) learn from this.

TECHNICAL

NOTE: to have a proper view of the visual effects offered by these shaders, it is recommended to use larger meshes that will be used as "hosts", please avoid rescaling them. Best way is to create a cube of desired size in modeling application and export it as FBX. My shader examples are made to work with cube with 3m sides (so 3x3x3). If you try this with stock 1m cube, it will most likely have weird visual artifacts, so edit map() function in xxx_RAYCAST.cginc to scale down the SDF primitives to fit. Ofcourse, also pay attention to have nice and clean UV so it all looks ok.

I tested these shaders under Unity 2019 for Windows and Unity 2021 for Linux. The Unity 2019 has quirks under Linux (so does 2021, but there are workarounds one can find on internet). They should ofcourse work within forward rendering inside built-in rendering pipeline.

 The shaders are designed to write to depth buffer and have a shadowcaster passes. For opaque shader, set to render at "geometry" queue, this means you should get a rendered "object" that is equal to normal meshes in scene. For transparent shader, which is set to write at "alpha test" queue, this is a bit different - if i remember correctly, transparent shaders usually don't write to depth buffer, but i tested and it appears to work so i decided to keep the depth write. Similarly, casting shadows for transparent shader is kind of wrong, but again i saw it worked, so same decision. :)

I wrote the transparent shader with some specific code to manage transparency - its not ideal and surely could be more refined, but to me it looked "good enough" for release into repository. One could use transparent shader with zero transparency to mimic opaque shader, but the background grab pass will execute regardless, wasting precious GPU cycles.

 For the transparent shader's shadowcaster pass, i also decided to demonstrate "fake caustics" both as an example and an exercise. As i wrote at the beginning, there is a lot going on and prior knowlege will help understand it all.

 Both shaders feature a function that helps with writing to depth buffer. During my research i encountered examples that used separate code in C# that runs along the shader and helps it do proper depth write. I wasn't too pleased with this as i wanted to have a shader that is self-contained as much as possible. And thanks to help from Ben Golus, i managed to get this working. There is one unused function that tries to reconstruct point coordinates from available depth buffer and it should allow shader code to interpret and react to this point during raymarching phase. I think it worked, but i tested it long time ago and i'm not sure anymore. It was also created with help from Ben Golus.

