import cv2
import numpy as np
import os
import argparse
from pathlib import Path

def detect_image_format(file_path):
    ext = Path(file_path).suffix.lower()
    if ext in ['.jpg', '.jpeg']:
        return 'jpg'
    elif ext == '.pgm':
        return 'pgm'
    elif ext == '.ppm':
        return 'ppm'
    elif ext == '.png':
        return 'png'
    elif ext == '.bmp':
        return 'bmp'
    elif ext in ['.tif', '.tiff']:
        return 'tiff'
    else:
        try:
            with open(file_path, 'rb') as f:
                magic = f.read(2)
                if magic == b'P5' or magic == b'P2':
                    return 'pgm'
                elif magic == b'P6' or magic == b'P3':
                    return 'ppm'
        except:
            pass
        return 'unknown'

def read_pgm(file_path):
    with open(file_path, 'rb') as f:
        magic = f.readline().decode('ascii').strip()
        
        line = ''
        while True:
            line = f.readline().decode('ascii')
            if not line.startswith('#'):
                break
        
        width, height = map(int, line.strip().split())
        
        max_val_line = f.readline().decode('ascii').strip()
        max_val = int(max_val_line)
        
        if magic == 'P5':
            image_data = np.fromfile(f, dtype=np.uint16 if max_val > 255 else np.uint8)
            image = image_data.reshape((height, width))
        else:
            all_values = list(map(int, f.read().decode('ascii').split()))
            image = np.array(all_values, dtype=np.uint16 if max_val > 255 else np.uint8).reshape((height, width))
        
        return image, max_val, magic

def write_pgm(file_path, image, max_val=255, format_type='P5'):
    height, width = image.shape
    
    if format_type == 'P2':
        with open(file_path, 'w') as f:
            f.write("P2\n")
            f.write(f"# Resized image {width}x{height}\n")
            f.write(f"{width} {height}\n")
            f.write(f"{max_val}\n")
            
            pixel_count = 0
            line_buffer = ""
            for row in image:
                for pixel in row:
                    pixel_str = str(pixel)
                    if len(line_buffer) + len(pixel_str) + 1 > 70:
                        f.write(line_buffer.rstrip() + "\n")
                        line_buffer = ""
                    if line_buffer:
                        line_buffer += " " + pixel_str
                    else:
                        line_buffer = pixel_str
                    pixel_count += 1
            if line_buffer:
                f.write(line_buffer + "\n")
    else:
        with open(file_path, 'wb') as f:
            f.write(b"P5\n")
            f.write(f"# Resized image {width}x{height}\n".encode('ascii'))
            f.write(f"{width} {height}\n".encode('ascii'))
            f.write(f"{max_val}\n".encode('ascii'))
            image.astype(np.uint16 if max_val > 255 else np.uint8).tofile(f)

def read_ppm(file_path):
    with open(file_path, 'rb') as f:
        magic = f.readline().decode('ascii').strip()
        
        line = ''
        while True:
            line = f.readline().decode('ascii')
            if not line.startswith('#'):
                break
        
        width, height = map(int, line.strip().split())
        
        max_val_line = f.readline().decode('ascii').strip()
        max_val = int(max_val_line)
        
        if magic == 'P6':
            image_data = np.fromfile(f, dtype=np.uint8)
            image = image_data.reshape((height, width, 3))
        else:
            all_values = list(map(int, f.read().decode('ascii').split()))
            image = np.array(all_values, dtype=np.uint8).reshape((height, width, 3))
        
        return image, max_val, magic

def write_ppm(file_path, image, max_val=255, format_type='P6'):
    height, width, channels = image.shape
    
    if format_type == 'P3':
        with open(file_path, 'w') as f:
            f.write("P3\n")
            f.write(f"# Resized image {width}x{height}\n")
            f.write(f"{width} {height}\n")
            f.write(f"{max_val}\n")
            
            for row in image:
                for pixel in row:
                    f.write(f"{pixel[0]} {pixel[1]} {pixel[2]} ")
                f.write("\n")
    else:
        with open(file_path, 'wb') as f:
            f.write(b"P6\n")
            f.write(f"# Resized image {width}x{height}\n".encode('ascii'))
            f.write(f"{width} {height}\n".encode('ascii'))
            f.write(f"{max_val}\n".encode('ascii'))
            image.astype(np.uint8).tofile(f)

def resize_image(input_path, output_path, width=None, height=None, scale_factor=1.0, interpolation=cv2.INTER_LINEAR):
    try:
        if not os.path.exists(input_path):
            print(f"Error: Input file does not exist -> {input_path}")
            return False
        
        input_format = detect_image_format(input_path)
        print(f"Input format: {input_format}")
        
        if input_format == 'unknown':
            print(f"Error: Unsupported file format -> {input_path}")
            return False
        
        if input_format in ['jpg', 'png', 'bmp', 'tiff']:
            img = cv2.imread(input_path)
            if img is None:
                print(f"Error: Cannot read image -> {input_path}")
                return False
            
            if len(img.shape) == 3:
                img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            else:
                img_rgb = img
                
            original_height, original_width = img.shape[:2]
            max_val = 255
            
        elif input_format == 'pgm':
            img, max_val, magic = read_pgm(input_path)
            original_height, original_width = img.shape
            img_rgb = img
            
        elif input_format == 'ppm':
            img, max_val, magic = read_ppm(input_path)
            original_height, original_width, _ = img.shape
            img_rgb = img
            
        print(f"Original size: {original_width} x {original_height}")
        
        if width is not None and height is not None:
            target_width = width
            target_height = height
        elif width is not None:
            target_width = width
            target_height = int(original_height * (width / original_width))
        elif height is not None:
            target_height = height
            target_width = int(original_width * (height / original_height))
        else:
            target_width = int(original_width * scale_factor)
            target_height = int(original_height * scale_factor)
        
        print(f"Target size: {target_width} x {target_height}")
        
        if len(img_rgb.shape) == 3:
            resized_img = cv2.resize(img_rgb, (target_width, target_height), interpolation=interpolation)
        else:
            resized_img = cv2.resize(img_rgb, (target_width, target_height), interpolation=interpolation)
        
        if input_format in ['jpg', 'png', 'bmp', 'tiff']:
            if len(resized_img.shape) == 3:
                resized_bgr = cv2.cvtColor(resized_img, cv2.COLOR_RGB2BGR)
                cv2.imwrite(output_path, resized_bgr)
            else:
                cv2.imwrite(output_path, resized_img)
                
        elif input_format == 'pgm':
            write_pgm(output_path, resized_img, max_val, magic)
            
        elif input_format == 'ppm':
            write_ppm(output_path, resized_img, max_val, magic)
        
        print(f"Resize successful! Output file: {output_path}")
        print(f"Output format: {input_format}")
        print(f"Output size: {target_width} x {target_height}")
        return True
        
    except Exception as e:
        print(f"Error during resize: {e}")
        return False

def batch_resize(input_dir, output_dir, width=None, height=None, scale_factor=1.0, 
                 supported_formats=['jpg', 'jpeg', 'pgm', 'ppm', 'png', 'bmp', 'tiff']):
    if not os.path.exists(input_dir):
        print(f"Error: Input directory does not exist -> {input_dir}")
        return
    
    os.makedirs(output_dir, exist_ok=True)
    
    image_files = []
    for filename in os.listdir(input_dir):
        ext = Path(filename).suffix.lower()[1:]
        if ext in supported_formats:
            image_files.append(filename)
    
    if not image_files:
        print(f"No supported image files found in directory {input_dir}")
        return
    
    print(f"Found {len(image_files)} image files:")
    for img_file in image_files:
        print(f"  - {img_file}")
    
    success_count = 0
    for img_file in image_files:
        input_path = os.path.join(input_dir, img_file)
        output_path = os.path.join(output_dir, img_file)
        
        print(f"\nProcessing: {img_file}")
        success = resize_image(input_path, output_path, width, height, scale_factor)
        
        if success:
            success_count += 1
    
    print(f"\nBatch processing completed! Successfully processed {success_count}/{len(image_files)} files")

def main():
    parser = argparse.ArgumentParser(description='Universal image resize tool')
    parser.add_argument('input', help='Input image file or directory path')
    parser.add_argument('output', help='Output image file or directory path')
    parser.add_argument('-W', '--width', type=int, help='Target width')
    parser.add_argument('-H', '--height', type=int, help='Target height')
    parser.add_argument('-s', '--scale', type=float, default=1.0, help='Scale factor (default: 1.0)')
    parser.add_argument('-i', '--interpolation', default='linear', 
                       choices=['nearest', 'linear', 'cubic', 'area', 'lanczos'],
                       help='Interpolation method (default: linear)')
    parser.add_argument('-b', '--batch', action='store_true', help='Batch process directory')
    
    args = parser.parse_args()
    
    interpolation_map = {
        'nearest': cv2.INTER_NEAREST,
        'linear': cv2.INTER_LINEAR,
        'cubic': cv2.INTER_CUBIC,
        'area': cv2.INTER_AREA,
        'lanczos': cv2.INTER_LANCZOS4
    }
    interpolation = interpolation_map[args.interpolation]
    
    if args.batch:
        batch_resize(args.input, args.output, args.width, args.height, args.scale)
    else:
        resize_image(args.input, args.output, args.width, args.height, args.scale, interpolation)

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        main()
    else:
        print("Running...")
        resize_image("../data/color.jpeg", "../data/color_resized.jpg", width=320, height=240)
        resize_image("../data/chessboard.png", "../data/chessboard_resized.jpg", width=320, height=466)