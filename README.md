#  Copying FFmpeg Libs


See the following:

* https://forums.swift.org/t/is-swiftpm-support-c-language-link-custom-build-static-library-inside-targets/21614
* https://forums.swift.org/t/packaging-a-static-c-libraries-in-swift-package-manager/28323/2
* https://github.com/FranzBusch/swift-evolution/blob/baf4f09dac450c91ece59dee45b1288b18e02ba5/proposals/0000-swiftpm-binary-dependencies.md
* https://forums.swift.org/t/se-0272-package-manager-binary-dependencies/30753
* https://forums.swift.org/t/binary-frameworks-with-swiftpm/26225

```
cp ../SwiftFFmpeg/Sources/CFFmpeg/lib/*.a lib/
```

