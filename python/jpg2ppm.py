import cv2

def jpg_to_ppm_p3(jpg_path, ppm_path, comment="# Created by GIMP version 2.10.36 PNM plug-in"):
    img = cv2.imread(jpg_path)
    if img is None:
        print(f"Error: Cannot read image {jpg_path}")
        return

    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    height, width, channels = img_rgb.shape
    max_val = 255

    with open(ppm_path, "w") as f:
        f.write("P3\n")
        f.write(comment + "\n")
        f.write(f"{width} {height}\n")
        f.write(f"{max_val}\n")
        for row in img_rgb:
            for pixel in row:
                f.write(f"{pixel[0]} {pixel[1]} {pixel[2]} ")
            f.write("\n")

    print(f"Conversion successful! PPM file saved to {ppm_path}")

if __name__ == "__main__":
    jpg_to_ppm_p3("../data/color.jpeg", "../data/color.ppm")