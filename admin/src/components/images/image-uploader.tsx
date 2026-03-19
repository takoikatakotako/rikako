"use client";

import { useState, useCallback } from "react";
import { Button } from "@/components/ui/button";
import { Upload, X, Loader2 } from "lucide-react";
import { uploadImage } from "@/lib/api/images";
import { toast } from "sonner";

interface UploadedImage {
  imageId: number;
  cdnUrl: string;
}

interface ImageUploaderProps {
  images: UploadedImage[];
  onChange: (images: UploadedImage[]) => void;
}

export function ImageUploader({ images, onChange }: ImageUploaderProps) {
  const [uploading, setUploading] = useState(false);

  const handleFiles = useCallback(
    async (files: FileList) => {
      const validFiles = Array.from(files).filter(
        (f) => f.type === "image/png" || f.type === "image/jpeg",
      );
      if (validFiles.length === 0) {
        toast.error("PNG または JPEG ファイルを選択してください");
        return;
      }

      setUploading(true);
      try {
        const results: UploadedImage[] = [];
        for (const file of validFiles) {
          const res = await uploadImage(file);
          results.push({ imageId: res.imageId, cdnUrl: res.cdnUrl });
        }
        onChange([...images, ...results]);
        toast.success(`${results.length}件の画像をアップロードしました`);
      } catch {
        toast.error("画像のアップロードに失敗しました");
      } finally {
        setUploading(false);
      }
    },
    [images, onChange],
  );

  function handleDrop(e: React.DragEvent) {
    e.preventDefault();
    if (e.dataTransfer.files.length > 0) {
      handleFiles(e.dataTransfer.files);
    }
  }

  function handleDragOver(e: React.DragEvent) {
    e.preventDefault();
  }

  function removeImage(index: number) {
    onChange(images.filter((_, i) => i !== index));
  }

  return (
    <div className="space-y-3">
      <div
        onDrop={handleDrop}
        onDragOver={handleDragOver}
        className="flex flex-col items-center justify-center rounded-md border-2 border-dashed p-6 text-center transition-colors hover:border-primary"
      >
        {uploading ? (
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        ) : (
          <>
            <Upload className="mb-2 h-8 w-8 text-muted-foreground" />
            <p className="text-sm text-muted-foreground">
              ドラッグ＆ドロップ または
            </p>
            <label>
              <input
                type="file"
                accept="image/png,image/jpeg"
                multiple
                className="hidden"
                onChange={(e) => e.target.files && handleFiles(e.target.files)}
              />
              <span className="cursor-pointer text-sm font-medium text-primary underline-offset-4 hover:underline">
                ファイルを選択
              </span>
            </label>
          </>
        )}
      </div>

      {images.length > 0 && (
        <div className="grid grid-cols-4 gap-2">
          {images.map((img, index) => (
            <div key={img.imageId} className="group relative">
              <img
                src={img.cdnUrl}
                alt=""
                className="h-24 w-full rounded-md border object-cover"
              />
              <Button
                type="button"
                variant="destructive"
                size="icon"
                className="absolute -right-1 -top-1 h-5 w-5 opacity-0 transition-opacity group-hover:opacity-100"
                onClick={() => removeImage(index)}
              >
                <X className="h-3 w-3" />
              </Button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
