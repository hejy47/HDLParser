# There are some changes needed to the off-the-shelf GumTree to support HDLs:

You need to replace the following files to GumTree and rebuild GumTree:

```
gen.hdl -> gumTree/gen.hdl
build.gradle -> gumTree/build.gradle
settings.gradle -> gumTree/settings.gradle
List.java -> gumTree/client/src/main/java/com/github/gumtreediff/client/List.java
```