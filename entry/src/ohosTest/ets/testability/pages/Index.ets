@Entry
@ComponentV2
struct Index {
  @Local message: string = 'Running tests...';

  build() {
    Row() {
      Column() {
        Text(this.message)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
    }
    .height('100%')
  }
}
