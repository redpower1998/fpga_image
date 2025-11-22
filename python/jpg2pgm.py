import cv2
import numpy as np
import os

def jpg_to_pgm_p2(jpg_path, pgm_path, comment="# Created by jpg2pgm.py"):
    try:
        if not os.path.exists(jpg_path):
            raise FileNotFoundError(f"JPG file does not exist: {jpg_path}")
        
        img = cv2.imread(jpg_path)
        if img is None:
            print(f"Error: Cannot read image {jpg_path}")
            return False

        img_gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        height, width = img_gray.shape
        max_val = 255
        
        print(f"Input JPG dimensions: {width} x {height}")
        print(f"Grayscale image data range: [{img_gray.min()}, {img_gray.max()}]")

        with open(pgm_path, "w") as f:
            f.write("P2\n")
            f.write(f"{width} {height}\n")
            f.write(f"{max_val}\n")
            
            pixel_count = 0
            line_buffer = ""
            
            for row in img_gray:
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
        
        print(f"Conversion successful! PGM P2 file saved to {pgm_path}")
        print(f"Total pixels written: {pixel_count}")
        print(f"Output file dimensions: {width} x {height}")
        return True

    except FileNotFoundError as e:
        print(f"Error: File not found -> {jpg_path}")
        print(f"Detailed error: {e}")
        return False
    except Exception as e:
        print(f"Error occurred during conversion: {e}")
        return False

def jpg_to_pgm_p5(jpg_path, pgm_path, comment="# Created by jpg2pgm.py"):
    try:
        if not os.path.exists(jpg_path):
            raise FileNotFoundError(f"JPG file does not exist: {jpg_path}")
        
        img = cv2.imread(jpg_path)
        if img is None:
            print(f"Error: Cannot read image {jpg_path}")
            return False

        img_gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        height, width = img_gray.shape
        max_val = 255
        
        print(f"Input JPG dimensions: {width} x {height}")
        print(f"Grayscale image data range: [{img_gray.min()}, {img_gray.max()}]")

        with open(pgm_path, "wb") as f:
            f.write(b"P5\n")
            f.write((comment + "\n").encode('ascii'))
            f.write(f"{width} {height}\n".encode('ascii'))
            f.write(f"{max_val}\n".encode('ascii'))
            
            img_gray.tofile(f)
        
        print(f"Conversion successful! PGM P5 file saved to {pgm_path}")
        print(f"Output file dimensions: {width} x {height}")
        return True

    except FileNotFoundError as e:
        print(f"Error: File not found -> {jpg_path}")
        print(f"Detailed error: {e}")
        return False
    except Exception as e:
        print(f"Error occurred during conversion: {e}")
        return False

def convert_all_jpg_in_data(output_format="P2"):
    data_dir = "../data"
    
    if not os.path.exists(data_dir):
        print(f"Data directory does not exist: {data_dir}")
        return
    
    jpg_files = []
    for filename in os.listdir(data_dir):
        if filename.lower().endswith(('.jpg', '.jpeg')):
            jpg_files.append(filename)
    
    if not jpg_files:
        print("No JPG files found in data directory")
        return
    
    print(f"Found {len(jpg_files)} JPG files:")
    for jpg_file in jpg_files:
        print(f"  - {jpg_file}")
    
    success_count = 0
    for jpg_file in jpg_files:
        jpg_path = os.path.join(data_dir, jpg_file)
        pgm_filename = os.path.splitext(jpg_file)[0] + ".pgm"
        pgm_path = os.path.join(data_dir, pgm_filename)
        
        print(f"Converting: {jpg_file} -> {pgm_filename}")
        
        if output_format.upper() == "P2":
            success = jpg_to_pgm_p2(jpg_path, pgm_path)
        else:
            success = jpg_to_pgm_p5(jpg_path, pgm_path)
        
        if success:
            success_count += 1
    
    print(f"Batch conversion completed! Successfully converted {success_count}/{len(jpg_files)} files")

if __name__ == "__main__":
    jpg_to_pgm_p2("../data/gray1.jpg", "../data/gray1.pgm")
    jpg_to_pgm_p2("../data/baby.jpg", "../data/baby.pgm")
    jpg_to_pgm_p2("../data/in_erosion.jpg", "../data/in_erosion.pgm")
    jpg_to_pgm_p2("../data/chessboard_resized.jpg", "../data/chessboard_resized.pgm")