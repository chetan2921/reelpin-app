import receive_sharing_intent

class ShareViewController: RSIShareViewController {
  override func shouldAutoRedirect() -> Bool {
    return true
  }

  override func presentationAnimationDidFinish() {
    super.presentationAnimationDidFinish()
    navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = "Save"
  }
}
