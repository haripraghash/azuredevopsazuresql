CREATE TABLE [dbo].[Variants]
(
	[Id] INT NOT NULL IDENTITY CONSTRAINT pk_variants PRIMARY KEY, 
    [Color] NVARCHAR(100) NOT NULL,
	[Size] NVARCHAR(100) NOT NULL,
	[ProductId] INT NOT NULL,
	CONSTRAINT [FK_Variants_Products] FOREIGN KEY ([ProductId]) REFERENCES [Products]([Id])
)
