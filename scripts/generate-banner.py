import argparse
import base64
import os
from pathlib import Path

from openai import OpenAI
from PIL import Image


def main():
    parser = argparse.ArgumentParser(
        description="Generate a banner image for a blog post"
    )
    parser.add_argument("input_file", help="Path to the blog post file")
    args = parser.parse_args()

    input_path = Path(args.input_file)
    if not input_path.exists():
        print(f"❌ Error: Input file '{input_path}' not found.")
        return

    print(f"📄 Reading blog post content from: {input_path}")
    with open(input_path, "r") as f:
        post_text = f.read()
    print(f"📝 Loaded {len(post_text)} characters from blog post")

    # Truncate post_text to 32,000 characters
    max_length = 32000
    if len(post_text) > max_length:
        post_text = post_text[:max_length]
        print(f"⚠️ Blog post truncated to {max_length} characters for prompt.")

    # Artistic prompt for OpenAI
    prompt = f"""
    Create a high-resolution surrealist painting for a blog post title banner image.

    Composition and crop:
    - The final banner is center-cropped to 1920x280 from this image. Keep all important forms within the central 30% of the height.
    - Place the main visual interest across that central band.
    - Feel free to be creative with the composition.

    Readability and palette:
    - Ensure that the central area allows for white or black text to be easily readable.
    - Use a cohesive palette colors that match the post, if possible.

    Style and content constraints:
    - Surrealist painting style, rich in detail and texture.
    - Do not include any text, letters, numbers, logos, copyrighted characters, watermarks, or UI.

    Use the blog post content below as inspiration for the image.

    Blog post content:
    {post_text}
    """

    print("🔄 Initializing OpenAI client")
    client = OpenAI()

    print(f"🎨 Generating image for blog post...")
    result = client.images.generate(
        model="gpt-image-1", prompt=prompt, size="1536x1024"
    )

    if result.data and result.data[0].b64_json is not None:
        image_base64 = result.data[0].b64_json
        image_bytes = base64.b64decode(image_base64)

        # Save to images/banner.png in the same folder as input
        banner_dir = input_path.parent / "images"
        banner_dir.mkdir(exist_ok=True)
        banner_path = banner_dir / "banner.png"
        with open(banner_path, "wb") as f:
            f.write(image_bytes)
        print(f"✨ Success! Banner image saved to {banner_path}")

        # Crop the image to 1920x280 using Pillow
        try:
            with Image.open(banner_path) as img:
                width, height = img.size
                crop_width, crop_height = 1536, 480
                left = (width - crop_width) // 2
                top = (height - crop_height) // 2
                right = left + crop_width
                bottom = top + crop_height
                cropped = img.crop((left, top, right, bottom))
                cropped.save(banner_path)
            print(f"✂️ Cropped banner image to 1920x280 at {banner_path}")
        except Exception as e:
            print(f"❌ Error cropping image: {e}")
    else:
        print("❌ Error: No image data returned from the API")


if __name__ == "__main__":
    main()
