class FormUtils {
  static void clearFields({required List controllers}) {
    for(final controller in controllers) {
      controller.clear();
    }
  }
}