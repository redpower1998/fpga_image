import cv2
import numpy as np
import os

def ppm_to_jpg(ppm_path, jpg_path):
    try:
        if not os.path.exists(ppm_path):
            raise FileNotFoundError(f"PPM file not found: {ppm_path}")
        
        file_size = os.path.getsize(ppm_path)
        print(f"PPM file size: {file_size} bytes")
        
        with open(ppm_path, 'rb') as f:
            magic = f.readline().decode('ascii').strip()
            if magic not in ('P3', 'P6'):
                raise ValueError(f"Unsupported PPM format: {magic}. Only P3 and P6 are supported.")

            line = ''
            while True:
                line = f.readline().decode('ascii')
                if not line.startswith('#'):
                    break
            
            width, height = map(int, line.strip().split())
            print(f"PPM header dimensions: {width} x {height}")

            max_val = int(f.readline().decode('ascii').strip())
            
            expected_size = width * height * 3
            print(f"Expected data size: {expected_size} bytes")
            
            if magic == 'P6':
                image_data = np.fromfile(f, dtype=np.uint8)
                actual_size = len(image_data)
                print(f"Actual data size read: {actual_size} bytes")
                
                if actual_size != expected_size:
                    print(f"Warning: Data size mismatch! Expected {expected_size}, actual {actual_size}")
                    print("Attempting automatic size adjustment...")
                    
                    if actual_size % 3 != 0:
                        print(f"Warning: Data size is not a multiple of 3, actual size: {actual_size}")
                        print("Attempting to fix data...")
                        
                        truncated_size = actual_size - (actual_size % 3)
                        if truncated_size > 0:
                            print(f"Truncating data to {truncated_size} bytes")
                            image_data = image_data[:truncated_size]
                            actual_size = truncated_size
                        else:
                            raise ValueError(f"Data too small to process: {actual_size}")
                    
                    actual_pixels = actual_size // 3
                    print(f"Actual pixel count: {actual_pixels}")
                    
                    if actual_pixels % width == 0:
                        actual_height = actual_pixels // width
                        print(f"Adjusted dimensions: {width} x {actual_height}")
                        image = image_data.reshape((actual_height, width, 3))
                    else:
                        if actual_pixels % height == 0:
                            actual_width = actual_pixels // height
                            print(f"Adjusted dimensions: {actual_width} x {height}")
                            image = image_data.reshape((height, actual_width, 3))
                        else:
                            actual_side = int(np.sqrt(actual_pixels))
                            if actual_side * actual_side * 3 == actual_size:
                                print(f"Using square dimensions: {actual_side} x {actual_side}")
                                image = image_data.reshape((actual_side, actual_side, 3))
                            else:
                                print("Using original dimensions, auto padding/truncating data...")
                                if actual_size > expected_size:
                                    image_data = image_data[:expected_size]
                                    image = image_data.reshape((height, width, 3))
                                else:
                                    padded_data = np.zeros(expected_size, dtype=np.uint8)
                                    padded_data[:actual_size] = image_data
                                    image = padded_data.reshape((height, width, 3))
                else:
                    image = image_data.reshape((height, width, 3))
            
            else:
                all_values = list(map(int, f.read().decode('ascii').split()))
                actual_size = len(all_values)
                print(f"Actual data size read: {actual_size} values")
                
                if actual_size != expected_size:
                    print(f"Warning: Data size mismatch! Expected {expected_size}, actual {actual_size}")
                    print("Attempting automatic size adjustment...")
                    
                    if actual_size % 3 != 0:
                        print(f"Warning: Data size is not a multiple of 3, actual size: {actual_size}")
                        print("Attempting to fix data...")
                        
                        truncated_size = actual_size - (actual_size % 3)
                        if truncated_size > 0:
                            print(f"Truncating data to {truncated_size} values")
                            all_values = all_values[:truncated_size]
                            actual_size = truncated_size
                        else:
                            raise ValueError(f"Data too small to process: {actual_size}")
                    
                    actual_pixels = actual_size // 3
                    print(f"Actual pixel count: {actual_pixels}")
                    
                    if actual_pixels % width == 0:
                        actual_height = actual_pixels // width
                        print(f"Adjusted dimensions: {width} x {actual_height}")
                        image = np.array(all_values, dtype=np.uint8).reshape((actual_height, width, 3))
                    else:
                        if actual_pixels % height == 0:
                            actual_width = actual_pixels // height
                            print(f"Adjusted dimensions: {actual_width} x {height}")
                            image = np.array(all_values, dtype=np.uint8).reshape((height, actual_width, 3))
                        else:
                            actual_side = int(np.sqrt(actual_pixels))
                            if actual_side * actual_side * 3 == actual_size:
                                print(f"Using square dimensions: {actual_side} x {actual_side}")
                                image = np.array(all_values, dtype=np.uint8).reshape((actual_side, actual_side, 3))
                            else:
                                print("Using original dimensions, auto padding/truncating data...")
                                if actual_size > expected_size:
                                    all_values = all_values[:expected_size]
                                    image = np.array(all_values, dtype=np.uint8).reshape((height, width, 3))
                                else:
                                    padded_values = [0] * expected_size
                                    for i in range(min(actual_size, expected_size)):
                                        padded_values[i] = all_values[i]
                                    image = np.array(padded_values, dtype=np.uint8).reshape((height, width, 3))
                else:
                    image = np.array(all_values, dtype=np.uint8).reshape((height, width, 3))

            print(f"Final image dimensions: {image.shape}")
            
            if image.dtype != np.uint8:
                image = image.astype(np.uint8)
            
            image_bgr = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
            
            cv2.imwrite(jpg_path, image_bgr)
            
            print(f"Conversion successful! JPG file saved to: {jpg_path}")
            print(f"Output image dimensions: {image_bgr.shape}")

    except FileNotFoundError as e:
        print(f"Error: File not found -> {ppm_path}")
        print(f"Detailed error: {e}")
    except Exception as e:
        print(f"Conversion failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    ppm_to_jpg("../data/love.ppm", "../data/love.jpg")
    ppm_to_jpg("../data/rgb1.ppm", "../data/rgb1.jpg")