+++
title = "Game Jam - Rogue Alchemy"

[taxonomies]
tags = ["Rust", "Bevy", "Game Jam"]

[extra]
date = "2022"
img = "img2.png"
+++

[Find the code here](https://github.com/Brick5215/bevy_metroidvania_gamejam)

Made for the 2022 Metroidvania Month 15 Game Jam. [Find the project page here](https://benjamin5215.itch.io/stars-of-rogue).

My First proper project using the [Bevy Game Engine](https://bevyengine.org/). As a relatively new and
developing engine, both now and back in 2022, learning and using Bevy at the time was a bit of a challenge.
While it was something I'd dabbled and experimented with before, actually putting all the pieces together was
more challenging than expected.

The main challenge came from the physics behind the project. Having not used much physics in the past outside
of builtin game engine systems and simple 2d aabb collision systems, I decided to use a physics library,
especially given that Bevy uses an entity component system (ECS) to further complicate potential physics steps
and resolutions. 

The physics library chosen was [Heron](https://github.com/jcornaz/heron) which to complicate things again, was
still heavily in development, needed features at the time for the project only available on the git repo and
not on the current release.

As such, the final result was not great. While everything worked for the most part, there were some issues
with the physics, mainly some floors would prevent the player from jumping. I couln't understand why. Most
areas worked fine most of the time, some tests having no problems at all while other times you'd get stuck for
no apparent reason.

Additionally, my movement with the physics needed work. The movement was floaty, not super responsive and jumps
with one of the climbing axe abilities was a little slow and sometimes inconsistent.

As a final note, for the game jam, I worked until the last minute, my local builds working as expected the
entire time only to make a web build at the end assuming it would work the same. Assumably due to differences
between WebGL and whatever API Bevy was using, the web build had texture atlas issues regarding whitespace that
I only found out then and then had no time to fix which is why you may see that on the web build on itch.io.

Of course, the benefit was that I at least had a web build unlike one of my previous game jams, [Abyss Boss
Drop](@/projects/abyss/index.md).

Regardless of all this, I'm still glad I did it and learnt and explored a good amount or Rust and the Bevy
engine. Looking back, there's a lot of things I'd do very differently today.


<img src = "img1.png">

<img src = "img2.png">

<img src = "img3.png">

<br><br>

## TODO (Sorry)
