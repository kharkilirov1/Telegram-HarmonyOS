import { TgUiTokens } from '../tokens/TgUiTokens';
import { localized } from '../../../core/utils/AppResource';

// Resolve against this mounted ability/module and its current theme, including
// cross-HAP test contexts. No resource IDs or palette values are duplicated.
export function resolvePhotoSelectionPreviewColor(context: UIContext, resourceName: string): number {
  const host = context.getHostContext();
  if (host === undefined) throw new Error('Mounted photo preview resource context is unavailable');
  return host.resourceManager.getColorByNameSync(resourceName) >>> 0;
}

// One instance per URI: invalid/new sources cannot retain the prior photo.
@ComponentV2
struct TgSelectedPhotoImage {
  @Require @Param uri: string;
  @Require @Param idPrefix: string;
  @Event onImageLoad: (uri: string, success: boolean, width: number, height: number,
    contentWidth: number, contentHeight: number) => void =
    (_uri: string, _success: boolean, _width: number, _height: number,
      _contentWidth: number, _contentHeight: number): void => {};
  @Local private loaded: boolean = false;
  @Local private failed: boolean = false;

  build() {
    Stack() {
      Image(this.uri)
        .id(this.idPrefix + '-image')
        .width('100%')
        .height(TgUiTokens.PHOTO_SELECTION_IMAGE_HEIGHT)
        .objectFit(ImageFit.Contain)
        .autoResize(true)
        .onComplete((event) => {
          if (event !== undefined && event.loadingStatus === 1 && event.width > 0 && event.height > 0 &&
            event.contentWidth > 0 && event.contentHeight > 0) {
            this.loaded = true;
            this.failed = false;
            this.onImageLoad(this.uri, true, event.width, event.height, event.contentWidth, event.contentHeight);
          }
        })
        .onError(() => {
          this.loaded = false;
          this.failed = true;
          this.onImageLoad(this.uri, false, 0, 0, 0, 0);
        })
      if (this.failed) {
        Text(localized($r('app.string.composer_photo_preview_unavailable').id, 'Photo unavailable'))
          .id(this.idPrefix + '-error')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(resolvePhotoSelectionPreviewColor(this.getUIContext(), TgUiTokens.COLOR_TEXT_TITLE_RESOURCE_NAME))
      } else if (!this.loaded) {
        Text(localized($r('app.string.composer_photo_preview_loading').id, 'Loading photo…'))
          .id(this.idPrefix + '-loading')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(resolvePhotoSelectionPreviewColor(this.getUIContext(), TgUiTokens.COLOR_TEXT_TITLE_RESOURCE_NAME))
      }
    }
    .width('100%')
    .height(TgUiTokens.PHOTO_SELECTION_IMAGE_HEIGHT)
    .backgroundColor(resolvePhotoSelectionPreviewColor(this.getUIContext(), TgUiTokens.COLOR_BG_SECONDARY_RESOURCE_NAME))
    .borderRadius(TgUiTokens.RADIUS_8)
    .clip(true)
  }
}

@ComponentV2
export struct TgPhotoSelectionPreview {
  @Require @Param uris: string[];
  @Param disabled: boolean = false;
  @Param idPrefix: string = 'photo-selection-preview';
  @Event onRemove: (uri: string) => void = (_uri: string): void => {};
  @Event onMove: (uri: string, direction: number) => void = (_uri: string, _direction: number): void => {};
  @Event onImageLoad: (uri: string, success: boolean, width: number, height: number,
    contentWidth: number, contentHeight: number) => void =
    (_uri: string, _success: boolean, _width: number, _height: number,
      _contentWidth: number, _contentHeight: number): void => {};
  @Local private selectedUri: string = '';

  @Monitor('uris')
  onSelectionChanged(): void {
    if (!this.uris.includes(this.selectedUri)) this.selectedUri = this.uris.length > 0 ? this.uris[0] : '';
  }

  private currentUri(): string {
    return this.uris.includes(this.selectedUri) ? this.selectedUri : (this.uris.length > 0 ? this.uris[0] : '');
  }

  private photoLabel(index: number): string {
    return localized($r('app.string.composer_photo_preview_photo').id, 'Photo') + ' ' +
      (index + 1).toString() + ' / ' + this.uris.length.toString();
  }

  private requestMove(direction: number): void {
    const uri = this.currentUri();
    const index = this.uris.indexOf(uri);
    if (!this.disabled && index >= 0 && index + direction >= 0 && index + direction < this.uris.length) {
      this.onMove(uri, direction);
    }
  }

  private requestRemove(): void {
    const uri = this.currentUri();
    if (!this.disabled && this.uris.includes(uri)) this.onRemove(uri);
  }

  build() {
    if (this.uris.length > 0) {
      Column({ space: TgUiTokens.SPACE_8 }) {
        Text(this.photoLabel(this.uris.indexOf(this.currentUri())))
          .id(this.idPrefix + '-position')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(resolvePhotoSelectionPreviewColor(this.getUIContext(), TgUiTokens.COLOR_TEXT_TITLE_RESOURCE_NAME))
        ForEach([this.currentUri()], (uri: string) => {
          TgSelectedPhotoImage({
            uri: uri, idPrefix: this.idPrefix,
            onImageLoad: (loadedUri: string, success: boolean, width: number, height: number,
              contentWidth: number, contentHeight: number): void => {
              if (loadedUri === this.currentUri()) {
                this.onImageLoad(loadedUri, success, width, height, contentWidth, contentHeight);
              }
            }
          })
        }, (uri: string): string => uri)
        Scroll() {
          Row({ space: TgUiTokens.SPACE_8 }) {
            ForEach(this.uris, (uri: string) => {
              Button() {
                Stack({ alignContent: Alignment.BottomEnd }) {
                  Image(uri)
                    .width(TgUiTokens.PHOTO_SELECTION_THUMB_SIZE)
                    .height(TgUiTokens.PHOTO_SELECTION_THUMB_SIZE)
                    .objectFit(ImageFit.Cover)
                    .autoResize(true)
                  Text((this.uris.indexOf(uri) + 1).toString())
                    .id(this.idPrefix + '-ordinal-' + this.uris.indexOf(uri).toString())
                    .fontSize(TgUiTokens.FONT_META_SIZE)
                    .fontColor(resolvePhotoSelectionPreviewColor(this.getUIContext(), TgUiTokens.COLOR_TEXT_TITLE_RESOURCE_NAME))
                    .backgroundColor(resolvePhotoSelectionPreviewColor(this.getUIContext(), TgUiTokens.COLOR_BG_SECONDARY_RESOURCE_NAME))
                    .padding(TgUiTokens.SPACE_2)
                }
              }
              .id(this.idPrefix + '-thumb-' + this.uris.indexOf(uri).toString())
              .type(ButtonType.Normal)
              .padding(0)
              .clip(true)
              .border({ width: TgUiTokens.PHOTO_SELECTION_BORDER_WIDTH,
                color: resolvePhotoSelectionPreviewColor(this.getUIContext(), uri === this.currentUri() ?
                  TgUiTokens.COLOR_ICON_PRIMARY_RESOURCE_NAME : TgUiTokens.COLOR_SEPARATOR_RESOURCE_NAME) })
              .borderRadius(TgUiTokens.RADIUS_8)
              .accessibilityText(this.photoLabel(this.uris.indexOf(uri)))
              .enabled(!this.disabled)
              .onClick(() => { if (!this.disabled) this.selectedUri = uri; })
            }, (uri: string): string => uri)
          }
        }
        .id(this.idPrefix + '-strip')
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        Row({ space: TgUiTokens.SPACE_4 }) {
          Button(localized($r('app.string.composer_photo_preview_move_earlier').id, 'Move earlier'))
            .id(this.idPrefix + '-move-earlier')
            .layoutWeight(1)
            .height(TgUiTokens.PHOTO_SELECTION_CONTROL_HEIGHT)
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .labelStyle({ maxLines: 2 })
            .enabled(!this.disabled && this.uris.indexOf(this.currentUri()) > 0)
            .onClick(() => this.requestMove(-1))
          Button(localized($r('app.string.composer_photo_preview_remove').id, 'Remove photo'))
            .id(this.idPrefix + '-remove')
            .layoutWeight(1)
            .height(TgUiTokens.PHOTO_SELECTION_CONTROL_HEIGHT)
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .labelStyle({ maxLines: 2 })
            .enabled(!this.disabled)
            .onClick(() => this.requestRemove())
          Button(localized($r('app.string.composer_photo_preview_move_later').id, 'Move later'))
            .id(this.idPrefix + '-move-later')
            .layoutWeight(1)
            .height(TgUiTokens.PHOTO_SELECTION_CONTROL_HEIGHT)
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .labelStyle({ maxLines: 2 })
            .enabled(!this.disabled && this.uris.indexOf(this.currentUri()) < this.uris.length - 1)
            .onClick(() => this.requestMove(1))
        }
        .width('100%')
      }
      .id(this.idPrefix)
      .width('100%')
      .padding(TgUiTokens.SPACE_8)
      .backgroundColor(resolvePhotoSelectionPreviewColor(this.getUIContext(), TgUiTokens.COLOR_BG_PRIMARY_RESOURCE_NAME))
    }
  }
}
