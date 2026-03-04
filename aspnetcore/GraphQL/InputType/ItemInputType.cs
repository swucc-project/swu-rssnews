namespace rssnews.GraphQL.InputType
{
    public class ItemInputType : InputObjectType<ItemInput>
    {
        protected override void Configure(IInputObjectTypeDescriptor<ItemInput> descriptor)
        {
            descriptor.Name("ItemInput");

            descriptor.Field(i => i.Title)
                .Type<NonNullType<StringType>>();

            descriptor.Field(i => i.Link)
                .Type<NonNullType<StringType>>();

            descriptor.Field(i => i.Description)
                .Type<NonNullType<StringType>>();

            descriptor.Field(i => i.PublishedDate)
                .Type<NonNullType<DateTimeType>>()
                .Name("publishedDate");

            descriptor.Field(i => i.CategoryId)
                .Type<NonNullType<IntType>>()
                .Name("categoryId");

            descriptor.Field(i => i.AuthorId)
                .Type<NonNullType<StringType>>()
                .Name("authorId");
        }
    }
}