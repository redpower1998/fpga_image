import cv2
import numpy as np
import os

def pgm_to_jpg(pgm_path, jpg_path):
    try:
        if not os.path.exists(pgm_path):
            raise FileNotFoundError(f"PGM file does not exist: {pgm_path}")
        
        file_size = os.path.getsize(pgm_path)
        print(f"PGM file size: {file_size} bytes")
        
        with open(pgm_path, 'rb') as f:
            magic = f.readline().decode('ascii').strip()
            if magic not in ('P2', 'P5'):
                raise ValueError(f"Unsupported PGM format: {magic}. Only P2 and P5 are supported.")

            line = ''
            while True:
                line = f.readline().decode('ascii')
                if not line.startswith('#'):
                    break
            
            width, height = map(int, line.strip().split())
            print(f"PGM header dimensions: {width} x {height}")

            max_val_line = f.readline().decode('ascii').strip()
            max_val = int(max_val_line)
            print(f"Maximum pixel value: {max_val}")
            
            need_normalize = max_val > 255
            if need_normalize:
                print(f"Detected PGM with more than 8 bits (max value {max_val}), will normalize to 8 bits")
            
            expected_size = width * height
            print(f"Expected data size: {expected_size} pixels")
            
            if magic == 'P5':
                image_data = np.fromfile(f, dtype=np.uint16 if max_val > 255 else np.uint8)
                actual_size = len(image_data)
                print(f"Actual data size read: {actual_size} pixels")
                
                if actual_size != expected_size:
                    print(f"Warning: Data size mismatch! Expected {expected_size}, actual {actual_size}")
                    print("Attempting automatic size adjustment...")
                    
                    if actual_size == 0:
                        raise ValueError("Read data is empty")
                    
                    actual_pixels = actual_size
                    print(f"Actual pixel count: {actual_pixels}")
                    
                    if actual_pixels % width == 0:
                        actual_height = actual_pixels // width
                        print(f"Adjusted dimensions: {width} x {actual_height}")
                        image = image_data.reshape((actual_height, width))
                    else:
                        if actual_pixels % height == 0:
                            actual_width = actual_pixels // height
                            print(f"Adjusted dimensions: {actual_width} x {height}")
                            image = image_data.reshape((height, actual_width))
                        else:
                            actual_side = int(np.sqrt(actual_pixels))
                            if actual_side * actual_side == actual_size:
                                print(f"Using square dimensions: {actual_side} x {actual_side}")
                                image = image_data.reshape((actual_side, actual_side))
                            else:
                                print("Using original dimensions, auto padding/truncating data...")
                                if actual_size > expected_size:
                                    image_data = image_data[:expected_size]
                                    image = image_data.reshape((height, width))
                                else:
                                    padded_data = np.zeros(expected_size, dtype=image_data.dtype)
                                    padded_data[:actual_size] = image_data
                                    image = padded_data.reshape((height, width))
                else:
                    image = image_data.reshape((height, width))
            
            else:
                all_values = list(map(int, f.read().decode('ascii').split()))
                actual_size = len(all_values)
                print(f"Actual data size read: {actual_size} values")
                
                if actual_size != expected_size:
                    print(f"Warning: Data size mismatch! Expected {expected_size}, actual {actual_size}")
                    print("Attempting automatic size adjustment...")
                    
                    if actual_size == 0:
                        raise ValueError("Read data is empty")
                    
                    actual_pixels = actual_size
                    print(f"Actual pixel count: {actual_pixels}")
                    
                    if actual_pixels % width == 0:
                        actual_height = actual_pixels // width
                        print(f"Adjusted dimensions: {width} x {actual_height}")
                        image = np.array(all_values, dtype=np.uint16 if max_val > 255 else np.uint8).reshape((actual_height, width))
                    else:
                        if actual_pixels % height == 0:
                            actual_width = actual_pixels // height
                            print(f"Adjusted dimensions: {actual_width} x {height}")
                            image = np.array(all_values, dtype=np.uint16 if max_val > 255 else np.uint8).reshape((height, actual_width))
                        else:
                            actual_side = int(np.sqrt(actual_pixels))
                            if actual_side * actual_side == actual_size:
                                print(f"Using square dimensions: {actual_side} x {actual_side}")
                                image = np.array(all_values, dtype=np.uint16 if max_val > 255 else np.uint8).reshape((actual_side, actual_side))
                            else:
                                print("Using original dimensions, auto padding/truncating data...")
                                if actual_size > expected_size:
                                    all_values = all_values[:expected_size]
                                    image = np.array(all_values, dtype=np.uint16 if max_val > 255 else np.uint8).reshape((height, width))
                                else:
                                    padded_values = [0] * expected_size
                                    for i in range(min(actual_size, expected_size)):
                                        padded_values[i] = all_values[i]
                                    image = np.array(padded_values, dtype=np.uint16 if max_val > 255 else np.uint8).reshape((height, width))
                else:
                    image = np.array(all_values, dtype=np.uint16 if max_val > 255 else np.uint8).reshape((height, width))

            print(f"Original image data type: {image.dtype}")
            print(f"Original image data range: [{image.min()}, {image.max()}]")
            
            if need_normalize:
                if image.max() > 0:
                    image_8bit = (image.astype(np.float32) / image.max() * 255).astype(np.uint8)
                    print(f"Normalized data range: [{image_8bit.min()}, {image_8bit.max()}]")
                else:
                    image_8bit = image.astype(np.uint8)
                    print("Image is all black, directly converting to uint8")
            else:
                image_8bit = image.astype(np.uint8)
                print("Image is already 8-bit, no normalization needed")

            print(f"Final image dimensions: {image_8bit.shape}")
            
            if image_8bit.dtype != np.uint8:
                image_8bit = image_8bit.astype(np.uint8)
            
            cv2.imwrite(jpg_path, image_8bit)
            
            print(f"Conversion successful! JPG file saved to: {jpg_path}")
            print(f"Output image dimensions: {image_8bit.shape}")

    except FileNotFoundError as e:
        print(f"Error: File not found -> {pgm_path}")
        print(f"Detailed error: {e}")
    except Exception as e:
        print(f"Conversion failed: {e}")
        import traceback
        traceback.print_exc()

def convert_all_pgm_in_data():
    data_dir = "../data"
    if not os.path.exists(data_dir):
        print(f"Data directory does not exist: {data_dir}")
        return
    
    pgm_files = [f for f in os.listdir(data_dir) if f.lower().endswith('.pgm')]
    
    if not pgm_files:
        print("No PGM files found in data directory")
        return
    
    print(f"Found {len(pgm_files)} PGM files:")
    for pgm_file in pgm_files:
        print(f"  - {pgm_file}")
    
    for pgm_file in pgm_files:
        pgm_path = os.path.join(data_dir, pgm_file)
        jpg_file = pgm_file.replace('.pgm', '.jpg').replace('.PGM', '.jpg')
        jpg_path = os.path.join(data_dir, jpg_file)
        
        print(f"Converting {pgm_file}")
        pgm_to_jpg(pgm_path, jpg_path)

if __name__ == "__main__":
    pgm_to_jpg("../data/gray1.pgm", "../data/gray1.jpg")
    pgm_to_jpg("../data/baby.pgm", "../data/baby.jpg")
    pgm_to_jpg("../data/in_erosion.pgm", "../data/in_erosion.jpg")